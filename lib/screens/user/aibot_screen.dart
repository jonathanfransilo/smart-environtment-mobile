import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:sirkular_app/services/chatbot_service.dart';
import 'package:sirkular_app/widgets/robot_3d_avatar.dart';
import 'jadwal_pengambilan_screen.dart';
import 'riwayat_pengambilan_screen.dart';
import 'payment_method_screen.dart';
import 'payment_process_screen.dart';
import 'tambah_akun_layanan_screen.dart';

class AIBotScreen extends StatefulWidget {
  final String? userName;
  final String? serviceAccountId;
  const AIBotScreen({super.key, this.userName, this.serviceAccountId});
  @override
  State<AIBotScreen> createState() => _AIBotScreenState();
}

class _AIBotScreenState extends State<AIBotScreen>
    with TickerProviderStateMixin {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ChatbotService _chatbotService = ChatbotService();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  bool _isAvailable = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _isTyping = false;
  String _recognizedText = '';
  String _lastSpokenText = '';

  Timer? _silenceTimer;
  static const _silenceTimeout = Duration(milliseconds: 1800);
  bool _hasAutoSent = false;

  // Call timer
  int _callSeconds = 0;
  Timer? _callTimer;

  // Latest response (subtitle display)
  String _latestBotResponse = '';
  List<ChatbotNavAction>? _latestActions;

  // Internal history
  final List<Map<String, dynamic>> _conversations = [];
  // Store latest invoice data for payment navigation
  List<Map<String, dynamic>>? _pendingInvoiceData;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  final List<double> _waveHeights = List.generate(24, (i) => 0.2);
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initSpeech();
    _initTts();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callSeconds++);
    });
    
    // Initial greeting
    _conversations.add({
      'role': 'bot',
      'type': 'text',
      'content': 'Hello! I am your Smart AI. 🤖\n\nI can speak and read your messages. Is there anything I can help you with regarding waste management or today\'s pickup schedule?',
      'time': _getCurrentTime(),
    });
    
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_isSpeaking) {
        _speak('Hello! I am your Smart AI. How can I help you today?');
      }
    });
  }

  void _initAnimations() {
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _waveController = AnimationController(duration: const Duration(milliseconds: 150), vsync: this)
      ..addListener(() {
        if (_isListening) {
          setState(() {
            for (int i = 0; i < _waveHeights.length; i++) {
              _waveHeights[i] = 0.15 + _random.nextDouble() * 0.85;
            }
          });
        }
      });
    _fadeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
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

  // ==================== TTS ====================
  Future<void> _initTts() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(1.0);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setStartHandler(() { if (mounted) setState(() => _isSpeaking = true); });
    _flutterTts.setCompletionHandler(() { if (mounted) setState(() => _isSpeaking = false); });
    _flutterTts.setCancelHandler(() { if (mounted) setState(() => _isSpeaking = false); });
    _flutterTts.setErrorHandler((msg) {
      debugPrint('TTS Error: $msg');
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speak(String text) async {
    final cleanText = _cleanTextForSpeech(text);
    if (cleanText.isNotEmpty) {
      final isEnglish = _isEnglishResponse(text);
      await _flutterTts.setLanguage(isEnglish ? 'en-US' : 'id-ID');
      await _flutterTts.setSpeechRate(isEnglish ? 0.85 : 0.9);
      await _flutterTts.speak(cleanText);
    }
  }

  bool _isEnglishResponse(String text) {
    final lower = text.toLowerCase();
    final en = ['sure','here','your','you','the','for','how can','what','let me','check',
      'great','welcome','thank','happy to help','anything else','tip:','try asking',
      'i can help','good morning','good afternoon','good evening','payment','schedule',
      'pickup','bill','history','of course','feel free','glad'];
    final id = ['kamu','aku','saya','untuk','yang','dengan','dari','tagihan','jadwal',
      'jemput','sampah','bisa bantu','terima kasih','senang','kabar','coba tanya',
      'silakan','tolong','bayar','riwayat','pembayaran','tentu','siap','bukakan','ketik'];
    int enS = 0, idS = 0;
    for (final w in en) { if (lower.contains(w)) enS++; }
    for (final w in id) { if (lower.contains(w)) idS++; }
    return enS > idS;
  }

  Future<void> _stopSpeaking() async {
    await _flutterTts.stop();
    if (mounted) setState(() { _isSpeaking = false; });
  }

  String _cleanTextForSpeech(String text) {
    String c = text;
    c = c.replaceAll(RegExp(
      r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|'
      r'[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|'
      r'[\u{FE00}-\u{FE0F}]|[\u{1F900}-\u{1F9FF}]|[\u{1FA00}-\u{1FA6F}]|'
      r'[\u{1FA70}-\u{1FAFF}]|[\u{200D}]|[\u{20E3}]|'
      r'[\u{FE0F}]|[\u{E0020}-\u{E007F}]', unicode: true), '');
    c = c.replaceAllMapped(RegExp(r'(\d)[\uFE0F\u20E3]+'), (m) => '${m.group(1)}, ');
    c = c.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '');
    c = c.replaceAllMapped(RegExp(r'\*(.+?)\*'), (m) => m.group(1) ?? '');
    c = c.replaceAll(RegExp('[•·▪▸►]'), '');
    c = c.replaceAll('→', ', ');
    c = c.replaceAll('"', '');
    c = c.replaceAllMapped(RegExp(r'Rp\.?\s*([\d\.]+)'), (m) {
      final a = m.group(1)?.replaceAll('.', '') ?? '';
      return '$a rupiah';
    });
    c = c.replaceAll(RegExp(r'[*_#~`]'), '');
    c = c.replaceAll(RegExp(r'\s+'), ' ').trim();
    return c;
  }

  // ==================== SPEECH ====================
  Future<void> _initSpeech() async {
    try {
      _isAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          _silenceTimer?.cancel();
          if (mounted) {
            final shouldProcess = _recognizedText.isNotEmpty && !_hasAutoSent;
            setState(() => _isListening = false);
            _pulseController.stop();
            _waveController.stop();
            if (shouldProcess) { _hasAutoSent = true; _processInput(_recognizedText); }
          }
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            if (mounted && _isListening) {
              _silenceTimer?.cancel();
              setState(() => _isListening = false);
              _pulseController.stop();
              _waveController.stop();
              if (_recognizedText.isNotEmpty && !_hasAutoSent) {
                _hasAutoSent = true;
                _processInput(_recognizedText);
              }
            }
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) { debugPrint('Speech init error: $e'); }
  }

  void _startListening() async {
    if (!_isAvailable) { _showSnackbar('Speech recognition tidak tersedia.'); return; }
    if (_isSpeaking) await _stopSpeaking();
    _silenceTimer?.cancel();
    _hasAutoSent = false;
    setState(() { _isListening = true; _recognizedText = ''; });
    _pulseController.repeat(reverse: true);
    _waveController.repeat();
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (!mounted) return;
        setState(() => _recognizedText = result.recognizedWords);
        if (result.finalResult && _recognizedText.isNotEmpty && !_hasAutoSent) {
          _silenceTimer?.cancel(); _hasAutoSent = true; _finishAndSend(); return;
        }
        _silenceTimer?.cancel();
        if (_recognizedText.isNotEmpty) {
          _silenceTimer = Timer(_silenceTimeout, () {
            if (mounted && _isListening && _recognizedText.isNotEmpty && !_hasAutoSent) {
              _hasAutoSent = true; _finishAndSend();
            }
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      listenOptions: stt.SpeechListenOptions(listenMode: stt.ListenMode.dictation),
    );
  }

  void _finishAndSend() async {
    final text = _recognizedText;
    _silenceTimer?.cancel();
    await _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
      _pulseController.stop();
      _waveController.stop();
      if (text.isNotEmpty) _processInput(text);
    }
  }

  void _stopListening() async {
    _silenceTimer?.cancel(); _hasAutoSent = true;
    await _speech.stop();
    setState(() => _isListening = false);
    _pulseController.stop(); _waveController.stop();
    if (_recognizedText.isNotEmpty) _processInput(_recognizedText);
  }

  // ==================== PROCESSING ====================
  void _handleSubmitted(String text) {
    if (text.trim().isEmpty || _isProcessing) return;
    _messageController.clear();
    setState(() {
      _isTyping = false;
    });
    _processInput(text);
  }

  Future<void> _processInput(String text, {bool isImage = false, Uint8List? imageBytes, String? imagePath}) async {
    if (text.trim().isEmpty && !isImage) return;
    
    if (_isSpeaking) await _stopSpeaking();
    
    setState(() {
      if (!isImage) _lastSpokenText = text;
      _isProcessing = true;
      if (isImage) {
        _conversations.add({
          'role': 'user', 
          'type': 'image', 
          'content': imagePath,
          'imageBytes': imageBytes,
          'time': _getCurrentTime()
        });
      } else {
        _conversations.add({'role': 'user', 'type': 'text', 'content': text, 'time': _getCurrentTime()});
      }
    });
    _scrollToBottom();

    if (isImage) {
      // Simulate image response
      Future.delayed(const Duration(seconds: 2), () async {
        if (mounted) {
          final responseMsg = _getImageResponse(text); // text holds fileName
          setState(() {
            _isProcessing = false;
            _latestBotResponse = responseMsg;
            _latestActions = null;
            _conversations.add({'role': 'bot', 'type': 'text', 'content': responseMsg, 'time': _getCurrentTime()});
          });
          _scrollToBottom();
          await _speak(responseMsg);
        }
      });
      return;
    }

    try {
      final response = await _chatbotService.sendMessage(
        text, serviceAccountId: widget.serviceAccountId, userName: widget.userName);
      if (mounted) {
        if (response.hasPaymentIntent) {
          _pendingInvoiceData = response.invoiceData;
        }

        setState(() {
          _isProcessing = false;
          _latestBotResponse = response.message;
          _latestActions = response.hasActions ? response.actions : null;
          _conversations.add({'role': 'bot', 'type': 'text', 'content': response.message, 'time': _getCurrentTime()});
        });
        _scrollToBottom();
        await _speak(response.message);

        if (mounted && response.hasAutoPayment) {
          await Future.delayed(const Duration(milliseconds: 1500));
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
        } else if (mounted && response.autoNavigate && response.actions.length == 1) {
          await Future.delayed(const Duration(milliseconds: 1500));
          if (mounted) {
            _handleNavAction(response.actions.first);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _latestBotResponse = 'Maaf, terjadi kesalahan saat memproses pesan Anda.';
          _latestActions = null;
          _conversations.add({'role': 'bot', 'type': 'text', 'content': _latestBotResponse, 'time': _getCurrentTime()});
        });
        _scrollToBottom();
        await _speak(_latestBotResponse);
      }
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String get _callDurationText {
    final m = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.poppins()),
      backgroundColor: Colors.red.shade400,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ==================== IMAGE ATTACHMENT ====================
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1B2838),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Take photo from',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  color: const Color(0xFF00E5CC),
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.photo_library_rounded,
                  color: const Color(0xFF4FC3F7),
                  label: 'Gallery',
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
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
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
        final Uint8List imageBytes = await photo.readAsBytes();
        final String fileName = photo.name;
        _processInput(fileName, isImage: true, imageBytes: imageBytes, imagePath: photo.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load image. Please try again.',
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

    if (lowerName.contains('sampah') || lowerName.contains('trash') || 
        lowerName.contains('waste') || lowerName.contains('garbage')) {
      return "Thank you for the photo, $name! 📸\n\n"
             "It looks like this photo is related to waste. Here's how I can help:\n\n"
             "🗑️ **Report Waste**\n"
             "   If you want to report a pile of waste, type \"buka pelaporan\"\n\n"
             "📅 **Pickup Schedule**\n"
             "   To check your pickup schedule, type \"jadwal\"\n\n"
             "Or tell me more about this photo! 😊";
    }

    return "Thank you for the photo, $name! 📸\n\n"
           "I've received your photo. I can't automatically analyze it right now, but I can help you with:\n\n"
           "🗑️ If this is a photo of **accumulated waste**, type \"buka pelaporan\" to report it\n\n"
           "📋 If this is a **payment receipt**, you can check the \"riwayat pembayaran\" menu\n\n"
           "💬 Or tell me what's in the photo and I'll try to help! 😊";
  }

  // ==================== NAVIGATION ====================
  void _handleNavAction(ChatbotNavAction action) {
    switch (action.route) {
      case 'jadwal_pengambilan':
        Navigator.push(context, MaterialPageRoute(builder: (ctx) => JadwalPengambilanScreen(
          serviceAccountId: int.tryParse(widget.serviceAccountId ?? '1') ?? 1)));
        break;
      case 'request_pengambilan':
        Navigator.pushNamed(context, '/express-request',
          arguments: {'serviceAccountId': widget.serviceAccountId});
        break;
      case 'riwayat_pengambilan':
        Navigator.push(context, MaterialPageRoute(builder: (ctx) => RiwayatPengambilanScreen(
          serviceAccountId: widget.serviceAccountId ?? '0',
          accountName: widget.userName ?? 'Akun')));
        break;
        case 'riwayat_pembayaran':
        Navigator.pushNamed(context, '/riwayat-pembayaran',
          arguments: {'serviceAccountId': widget.serviceAccountId});
        break;
      case 'artikel': Navigator.pushNamed(context, '/artikel'); break;
      case 'pelaporan':
        Navigator.pushNamed(context, '/pelaporan',
          arguments: {'serviceAccountId': widget.serviceAccountId});
        break;
      case 'tambah_akun_layanan':
        Navigator.push(context, MaterialPageRoute(
          builder: (ctx) => const TambahAkunLayananScreen()));
        break;
      case 'payment_method':
        _navigateToPayment();
        break;
      default: debugPrint('Unknown route: ${action.route}');
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

  IconData _getIconForAction(String n) {
    switch (n) {
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

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _callTimer?.cancel();
    _pulseController.dispose();
    _waveController.dispose();
    _fadeController.dispose();
    _speech.stop();
    _flutterTts.stop();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== UI ====================
  Color get _stateColor => _isListening
      ? const Color(0xFFFF6B6B) : _isSpeaking
      ? const Color(0xFF4FC3F7) : const Color(0xFF00E5CC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF1B2838), Color(0xFF0D1B2A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(children: [
              _buildTopBar(),
              const SizedBox(height: 4),
              _buildRobotSection(),
              const SizedBox(height: 4),
              _buildStatusText(),
              const SizedBox(height: 8),
              Expanded(flex: 4, child: _buildSubtitleArea()),
              _buildInputControls(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 12, 0),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_stateColor, _stateColor.withValues(alpha: 0.7)]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Smart AI', style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            Row(children: [
              Container(width: 6, height: 6,
                decoration: BoxDecoration(color: _stateColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(_isListening ? 'Listening...' : _isSpeaking ? 'Speaking...'
                  : _isProcessing ? 'Thinking...' : 'Online',
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.white54)),
            ]),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.call, size: 13, color: _stateColor),
            const SizedBox(width: 4),
            Text(_callDurationText, style: GoogleFonts.poppins(
              fontSize: 12, color: Colors.white60, fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
      ]),
    );
  }

  Widget _buildRobotSection() {
    RobotState robotState;
    if (_isListening) {
      robotState = RobotState.listening;
    } else if (_isProcessing) {
      robotState = RobotState.thinking;
    } else if (_isSpeaking) {
      robotState = RobotState.speaking;
    } else {
      robotState = RobotState.idle;
    }

    return SizedBox(
      height: 220,
      child: Robot3DAvatar(
        state: robotState,
        accentColor: _stateColor,
        size: 220,
      ),
    );
  }

  Widget _buildStatusText() {
    String text;
    IconData icon;
    if (_isListening) { text = 'Listening...'; icon = Icons.hearing_rounded; }
    else if (_isProcessing) { text = 'Thinking...'; icon = Icons.psychology_rounded; }
    else if (_isSpeaking) { text = 'Speaking...'; icon = Icons.record_voice_over_rounded; }
    else { text = _conversations.isEmpty ? 'Tap microphone or type message' : 'Ready to help'; icon = Icons.mic_none_rounded; }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Row(key: ValueKey(text), mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 15, color: _stateColor.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.poppins(fontSize: 13, color: Colors.white54)),
      ]),
    );
  }

  Widget _buildSubtitleArea() {
    List<Widget> children = [];

    // Suggestions when empty
    if (_conversations.isEmpty && !_isListening && !_isProcessing) {
      children.addAll([
        const SizedBox(height: 20),
        Center(child: Text('Try saying or typing:', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white30))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          _buildSuggestion('How much is my bill?', Icons.payment_rounded),
          _buildSuggestion('Waste pickup schedule', Icons.calendar_today_rounded),
          _buildSuggestion('Create service account', Icons.person_add_alt_1_rounded),
          _buildSuggestion('Open article', Icons.article_rounded),
        ]),
      ]);
    }

    // Chat history
    for (var msg in _conversations) {
      bool isUser = msg['role'] == 'user';
      if (msg['type'] == 'image') {
         children.add(_buildImageCaption(msg));
      } else {
         children.add(_buildCaption(msg['content'], isUser: isUser));
      }
    }

    // Currently recognized text (live)
    if (_isListening && _recognizedText.isNotEmpty) {
      children.add(_buildCaption(_recognizedText, isUser: true, isLive: true));
    }

    // Processing
    if (_isProcessing) {
      children.addAll([
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
            strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_stateColor))),
          const SizedBox(width: 8),
          Text('Processing...', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white38)),
        ]),
      ]);
    }

    // Latest actions
    if (_latestActions != null && _latestActions!.isNotEmpty && !_isProcessing) {
      children.addAll([
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
          children: _latestActions!.map((a) => _buildActionChip(a)).toList()),
      ]);
    }

    children.add(const SizedBox(height: 16));

    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: children,
    );
  }

  Widget _buildCaption(String text, {required bool isUser, bool isLive = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUser
            ? const Color(0xFF00BFA5).withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUser
            ? const Color(0xFF00BFA5).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
            size: 13, color: isUser ? const Color(0xFF00E5CC) : const Color(0xFF4FC3F7)),
          const SizedBox(width: 6),
          Text(isUser ? 'You' : 'Smart AI', style: GoogleFonts.poppins(fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isUser ? const Color(0xFF00E5CC) : const Color(0xFF4FC3F7))),
          if (isLive) ...[
            const Spacer(),
            Text('Listening...', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFFF6B6B))),
          ]
        ]),
        const SizedBox(height: 6),
        Text(text, style: GoogleFonts.poppins(
          fontSize: isUser ? 14 : 15,
          color: Colors.white.withValues(alpha: isUser ? 0.8 : 0.9),
          height: 1.5,
          fontStyle: isLive ? FontStyle.italic : FontStyle.normal)),
        if (!isUser) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (_isSpeaking && _latestBotResponse == text) {
                _stopSpeaking();
              } else {
                _speak(text);
              }
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.volume_up_rounded,
                size: 14, color: const Color(0xFF00E5CC)),
              const SizedBox(width: 4),
              Text('Replay',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500,
                  color: const Color(0xFF00E5CC))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildImageCaption(Map<String, dynamic> msg) {
    final Uint8List? imageBytes = msg['imageBytes'] as Uint8List?;
    Widget imageWidget;

    if (imageBytes != null) {
      imageWidget = Image.memory(
        imageBytes,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageErrorPlaceholder(),
      );
    } else if (kIsWeb) {
      imageWidget = Image.network(
        msg['content'],
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageErrorPlaceholder(),
      );
    } else {
      imageWidget = Image.file(
        File(msg['content']),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildImageErrorPlaceholder(),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00BFA5).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00BFA5).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.person_rounded,
            size: 13, color: Color(0xFF00E5CC)),
          const SizedBox(width: 6),
          Text('You', style: GoogleFonts.poppins(fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF00E5CC))),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200, maxWidth: double.infinity),
            child: SizedBox(width: double.infinity, child: imageWidget),
          ),
        ),
      ]),
    );
  }

  Widget _buildImageErrorPlaceholder() {
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(16),
      color: Colors.white.withValues(alpha: 0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_rounded, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          Text(
            'Image cannot be displayed',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(ChatbotNavAction action) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleNavAction(action),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF00897B)]),
            borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_getIconForAction(action.icon), color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(action.label, style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 10),
          ]),
        ),
      ),
    );
  }

  Widget _buildSuggestion(String label, IconData icon) {
    return GestureDetector(
      onTap: () => _processInput(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00E5CC).withValues(alpha: 0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: const Color(0xFF00E5CC)),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.poppins(
            fontSize: 12, color: const Color(0xFF00E5CC), fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildInputControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_isListening) ...[
            SizedBox(height: 30,
              child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_waveHeights.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: 3, height: 30 * _waveHeights[i],
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(2),
                    color: Color.lerp(const Color(0xFF00E5CC), const Color(0xFFFF6B6B), _waveHeights[i])),
                )),
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2838),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _showAttachmentOptions,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(Icons.add, color: Colors.white70, size: 24),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          onSubmitted: _handleSubmitted,
                          onChanged: (text) {
                            setState(() {
                              _isTyping = text.trim().isNotEmpty;
                            });
                          },
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Ask anything',
                            hintStyle: GoogleFonts.poppins(color: Colors.white54, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_isTyping)
                        GestureDetector(
                          onTap: () => _handleSubmitted(_messageController.text),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(Icons.send_rounded, color: Color(0xFF00E5CC), size: 22),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _isProcessing ? null : _isSpeaking ? _stopSpeaking
                              : (_isListening ? _stopListening : _startListening),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Icon(Icons.mic_none_rounded, color: Colors.white70, size: 22),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (ctx, child) => Transform.scale(
                  scale: _isListening ? _pulseAnimation.value : 1.0,
                  child: GestureDetector(
                    onTap: _isProcessing ? null : _isSpeaking ? _stopSpeaking
                        : (_isListening ? _stopListening : _startListening),
                    child: Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: _isListening ? const Color(0xFFFF6B6B) : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSpeaking ? Icons.stop_rounded 
                        : _isListening ? Icons.stop_rounded 
                        : Icons.graphic_eq_rounded,
                        color: _isListening ? Colors.white : Colors.black87, 
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

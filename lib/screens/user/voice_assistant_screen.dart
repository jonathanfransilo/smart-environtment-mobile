import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class VoiceAssistantScreen extends StatefulWidget {
  final String? userName;
  final String? serviceAccountId;
  const VoiceAssistantScreen({super.key, this.userName, this.serviceAccountId});
  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with TickerProviderStateMixin { 
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ChatbotService _chatbotService = ChatbotService();   
  final FlutterTts _flutterTts = FlutterTts();

  bool _isAvailable = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
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

  // ==================== TTS ====================
  Future<void> _initTts() async {
    await _flutterTts.setLanguage('id-ID');
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
            if (shouldProcess) { _hasAutoSent = true; _processVoiceInput(_recognizedText); }
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
                _processVoiceInput(_recognizedText);
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
      if (text.isNotEmpty) _processVoiceInput(text);
    }
  }

  void _stopListening() async {
    _silenceTimer?.cancel(); _hasAutoSent = true;
    await _speech.stop();
    setState(() => _isListening = false);
    _pulseController.stop(); _waveController.stop();
    if (_recognizedText.isNotEmpty) _processVoiceInput(_recognizedText);
  }

  // ==================== PROCESSING ====================
  Future<void> _processVoiceInput(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _lastSpokenText = text;
      _isProcessing = true;
      _conversations.add({'role': 'user', 'content': text, 'time': _getCurrentTime()});
    });
    try {
      final response = await _chatbotService.sendMessage(
        text, serviceAccountId: widget.serviceAccountId, userName: widget.userName);
      if (mounted) {
        // Store invoice data if this is a payment intent
        if (response.hasPaymentIntent) {
          _pendingInvoiceData = response.invoiceData;
        }

        setState(() {
          _isProcessing = false;
          _latestBotResponse = response.message;
          _latestActions = response.hasActions ? response.actions : null;
          _conversations.add({'role': 'bot', 'content': response.message, 'time': _getCurrentTime()});
        });
        await _speak(response.message);

        // Auto-navigate to PaymentProcessScreen if AI processed payment automatically
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
        }
        // Auto-navigate for regular nav actions (non-payment)
        else if (mounted && response.autoNavigate && response.actions.length == 1) {
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
        });
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
              _buildVoiceControls(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
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
              Text(_isListening ? 'Mendengarkan...' : _isSpeaking ? 'Berbicara...'
                  : _isProcessing ? 'Berpikir...' : 'Online',
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
    if (_isListening) { text = 'Mendengarkan...'; icon = Icons.hearing_rounded; }
    else if (_isProcessing) { text = 'Berpikir...'; icon = Icons.psychology_rounded; }
    else if (_isSpeaking) { text = 'Berbicara...'; icon = Icons.record_voice_over_rounded; }
    else { text = _conversations.isEmpty ? 'Tap mikrofon untuk mulai' : 'Siap mendengarkan'; icon = Icons.mic_none_rounded; }
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
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        // Show recognized text while listening
        if (_isListening && _recognizedText.isNotEmpty)
          _buildCaption(_recognizedText, isUser: true),
        // Show user's last text while processing/speaking
        if (!_isListening && _lastSpokenText.isNotEmpty && (_isProcessing || _isSpeaking || _latestBotResponse.isNotEmpty))
          _buildCaption(_lastSpokenText, isUser: true),
        // Processing indicator
        if (_isProcessing) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(
              strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(_stateColor))),
            const SizedBox(width: 8),
            Text('Memproses...', style: GoogleFonts.poppins(fontSize: 13, color: Colors.white38)),
          ]),
        ],
        // Bot response as subtitle
        if (_latestBotResponse.isNotEmpty && !_isProcessing) ...[
          const SizedBox(height: 12),
          _buildCaption(_latestBotResponse, isUser: false),
        ],
        // Action chips
        if (_latestActions != null && _latestActions!.isNotEmpty && !_isProcessing) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
            children: _latestActions!.map((a) => _buildActionChip(a)).toList()),
        ],
        // Suggestions
        if (_conversations.isEmpty && !_isListening) ...[
          const SizedBox(height: 20),
          Text('Coba katakan:', style: GoogleFonts.poppins(fontSize: 12, color: Colors.white30)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            _buildSuggestion('Berapa tagihan saya?', Icons.payment_rounded),
            _buildSuggestion('Jadwal jemput sampah', Icons.calendar_today_rounded),
            _buildSuggestion('Buat akun layanan', Icons.person_add_alt_1_rounded),
            _buildSuggestion('Buka artikel', Icons.article_rounded),
          ]),
        ],
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildCaption(String text, {required bool isUser}) {
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
          Icon(isUser ? Icons.mic_rounded : Icons.smart_toy_rounded,
            size: 13, color: isUser ? const Color(0xFF00E5CC) : const Color(0xFF4FC3F7)),
          const SizedBox(width: 6),
          Text(isUser ? 'Anda' : 'Smart AI', style: GoogleFonts.poppins(fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isUser ? const Color(0xFF00E5CC) : const Color(0xFF4FC3F7))),
        ]),
        const SizedBox(height: 6),
        Text(text, style: GoogleFonts.poppins(
          fontSize: isUser ? 14 : 15,
          color: Colors.white.withValues(alpha: isUser ? 0.65 : 0.88),
          height: 1.5,
          fontStyle: isUser ? FontStyle.italic : FontStyle.normal)),
        if (!isUser) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              if (_isSpeaking) {
                _stopSpeaking();
              } else {
                _speak(text);
              }
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                size: 14, color: _isSpeaking ? const Color(0xFFFF6B6B) : const Color(0xFF00E5CC)),
              const SizedBox(width: 4),
              Text(_isSpeaking ? 'Berhenti' : 'Putar ulang',
                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500,
                  color: _isSpeaking ? const Color(0xFFFF6B6B) : const Color(0xFF00E5CC))),
            ]),
          ),
        ],
      ]),
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
      onTap: () => _processVoiceInput(label),
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

  Widget _buildVoiceControls() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Waveform when listening
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
          // Button row
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            // Replay
            _buildCtrlBtn(Icons.replay_rounded, 'Ulangi', Colors.white38,
              onTap: _lastSpokenText.isNotEmpty ? () => _processVoiceInput(_lastSpokenText) : null),
            // Mic
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (ctx, child) => Transform.scale(
                scale: _isListening ? _pulseAnimation.value : 1.0,
                child: GestureDetector(
                  onTap: _isProcessing ? null : _isSpeaking ? _stopSpeaking
                      : (_isListening ? _stopListening : _startListening),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: _isListening
                            ? [const Color(0xFFFF6B6B), const Color(0xFFEE5A24)]
                            : _isProcessing
                                 ? [const Color(0xFF37474F), const Color(0xFF455A64)]
                                : [const Color(0xFF00E5CC), const Color(0xFF00BFA5)]),
                      boxShadow: [BoxShadow(
                        color: (_isListening ? const Color(0xFFFF6B6B) : const Color(0xFF00E5CC))
                            .withValues(alpha: 0.4),
                        blurRadius: 20, spreadRadius: 2)]),
                    child: Icon(
                      _isSpeaking ? Icons.stop_rounded
                          : _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
            // End call
            _buildCtrlBtn(Icons.call_end_rounded, 'Tutup',
              const Color(0xFFFF6B6B).withValues(alpha: 0.8),
              onTap: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 4),
          Text(
            _isSpeaking ? 'Tap untuk berhenti bicara'
                : _isListening ? 'Tap untuk berhenti'
                : _isProcessing ? 'Memproses...' : 'Tap untuk berbicara',
            style: GoogleFonts.poppins(fontSize: 11, color: Colors.white30, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildCtrlBtn(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
            border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'area_service.dart';
import 'config_service.dart';
import 'invoice_service.dart';
import 'payment_service.dart';
import 'resident_pickup_service.dart';
import 'service_account_service.dart';
import '../models/area_option.dart';
import '../models/payment_transaction.dart';

/// Represents a navigation action that the chatbot wants to perform
class ChatbotNavAction {
  final String route;
  final String label;
  final String icon;

  const ChatbotNavAction({
    required this.route,
    required this.label,
    required this.icon,
  });
}

/// Response from the chatbot, containing the text message and optional navigation actions
class ChatbotResponse {
  final String message;
  final List<ChatbotNavAction> actions;
  /// When true, the voice assistant should auto-navigate to the first action
  /// without requiring the user to tap a button.
  final bool autoNavigate;
  /// Invoice data for payment navigation — contains the list of unpaid invoices
  /// so the UI can navigate directly to PaymentMethodScreen.
  final List<Map<String, dynamic>>? invoiceData;
  /// Result of auto-payment — when the AI processes payment automatically,
  /// this contains the PaymentTransaction to navigate to PaymentProcessScreen.
  final PaymentTransaction? paymentResult;

  const ChatbotResponse({
    required this.message,
    this.actions = const [],
    this.autoNavigate = false,
    this.invoiceData,
    this.paymentResult,
  });

  bool get hasActions => actions.isNotEmpty;
  bool get hasPaymentIntent => invoiceData != null && invoiceData!.isNotEmpty;
  bool get hasAutoPayment => paymentResult != null;
}

class ChatbotService {
  final InvoiceService _invoiceService = InvoiceService();
  final PaymentService _paymentService = PaymentService();
  final ResidentPickupService _pickupService = ResidentPickupService();
  final AreaService _areaService = AreaService();
  final ServiceAccountService _serviceAccountService = ServiceAccountService();
  final ConfigService _configService = ConfigService();

  // ========== SERVICE ACCOUNT CREATION FLOW STATE ==========
  /// Steps: none → askName → askPhone → askKecamatan → askKelurahan → askRW → askAddress → confirm
  String _saStep = 'none';
  String _saLang = 'id';
  String? _saUserName;
  final Map<String, String> _saData = {};
  List<AreaOption> _saKecamatanOptions = [];
  List<AreaOption> _saKelurahanOptions = [];
  AreaOption? _saSelectedKecamatan;
  AreaOption? _saSelectedKelurahan;
  String? _saCityName;
  String? _saProvinceName;

  bool get _isInServiceAccountFlow => _saStep != 'none';

  void _resetServiceAccountFlow() {
    _saStep = 'none';
    _saData.clear();
    _saKecamatanOptions = [];
    _saKelurahanOptions = [];
    _saSelectedKecamatan = null;
    _saSelectedKelurahan = null;
  }

  Future<ChatbotResponse> sendMessage(String message, {String? serviceAccountId, String? userName}) async {
    final lowerMsg = message.toLowerCase().trim();

    // Detect language from message (default: 'id' = Indonesian)
    final lang = _detectLanguage(lowerMsg);

    // ===== MULTI-STEP: If in service account creation flow, handle step first =====
    if (_isInServiceAccountFlow) {
      // Allow cancel at any step
      if (_isCancelIntent(lowerMsg)) {
        _resetServiceAccountFlow();
        final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
        return ChatbotResponse(
          message: lang == 'en'
              ? "No problem, $name! 👍 The account creation has been cancelled.\n\nIs there anything else I can help you with? 😊"
              : "Oke, $name! 👍 Pembuatan akun layanan dibatalkan.\n\nAda hal lain yang bisa aku bantu? 😊",
        );
      }
      return await _handleServiceAccountStep(lowerMsg, message, userName);
    }

    // 1. Check for language switch request
    if (_isLanguageQuery(lowerMsg)) {
      return ChatbotResponse(message: _getLanguageResponse(lowerMsg, userName, lang));
    }

    // 2. Check for CREATE SERVICE ACCOUNT intent — HIGHEST PRIORITY
    if (_isCreateServiceAccountQuery(lowerMsg)) {
      return _handleCreateServiceAccountQuery(lowerMsg, userName, lang);
    }

    // 3. Check for navigation/menu opening requests
    if (_isNavigationQuery(lowerMsg)) {
      return _handleNavigationQuery(lowerMsg, userName, lang);
    }

    // 3. Check for greetings with Smart AI name
    if (_isGreetingWithAI(lowerMsg)) {
      return ChatbotResponse(message: _getPersonalGreeting(userName, lang));
    }

    // 4. Check for farewell / goodbye
    if (_isFarewell(lowerMsg)) {
      return ChatbotResponse(message: _getFarewellResponse(userName, lang));
    }

    // 5. Check for simple greetings
    if (_isSimpleGreeting(lowerMsg)) {
      return ChatbotResponse(message: _getSimpleGreetingResponse(userName, lang));
    }

    // 6. Check for how are you / apa kabar
    if (_isAskingHowAreYou(lowerMsg)) {
      return ChatbotResponse(message: _getHowAreYouResponse(userName, lang));
    }

    // 7. Check for thank you / terima kasih
    if (_isThankYou(lowerMsg)) {
      return ChatbotResponse(message: _getThankYouResponse(userName, lang));
    }

    // 8. Check for identity questions (who are you / siapa kamu)
    if (_isIdentityQuestion(lowerMsg)) {
      return ChatbotResponse(message: _getIdentityResponse(userName, lang));
    }

    // 9. Check for compliments
    if (_isCompliment(lowerMsg)) {
      return ChatbotResponse(message: _getComplimentResponse(userName, lang));
    }

    // 10. Check for apology / sorry
    if (_isApology(lowerMsg)) {
      return ChatbotResponse(message: _getApologyResponse(userName, lang));
    }

    // 11. Check for agreement / affirmation
    if (_isAffirmation(lowerMsg)) {
      return ChatbotResponse(message: _getAffirmationResponse(userName, lang));
    }

    // 12. Check for disagreement / negation
    if (_isNegation(lowerMsg)) {
      return ChatbotResponse(message: _getNegationResponse(userName, lang));
    }

    // 13. Check for emotional expressions
    if (_isEmotional(lowerMsg)) {
      return ChatbotResponse(message: _getEmotionalResponse(lowerMsg, userName, lang));
    }

    // 14. Check for joke / fun requests
    if (_isJokeRequest(lowerMsg)) {
      return ChatbotResponse(message: _getJokeResponse(userName, lang));
    }

    // 15. Check for time / date questions
    if (_isTimeQuery(lowerMsg)) {
      return ChatbotResponse(message: _getTimeResponse(userName, lang));
    }

    // 16. Check for about app questions
    if (_isAboutApp(lowerMsg)) {
      return ChatbotResponse(message: _getAboutAppResponse(userName, lang));
    }

    // 17. Check for PAY bill intent ("bayar tagihan", "pay my bill") — BEFORE bill check
    if (_isPayBillQuery(lowerMsg)) {
      return await _handlePayBillQuery(lowerMsg, serviceAccountId: serviceAccountId, userName: userName, lang: lang);
    }

    // 18. Check for Bill/Invoice/Payment queries (info only)
    if (_isBillQuery(lowerMsg)) {
      final msg = await _handleBillQuery(serviceAccountId: serviceAccountId, userName: userName, lang: lang);
      return ChatbotResponse(message: msg);
    }

    // 19. Check for Schedule/Pickup queries
    if (_isScheduleQuery(lowerMsg)) {
      final msg = await _handleScheduleQuery(serviceAccountId: serviceAccountId, userName: userName, lang: lang);
      return ChatbotResponse(message: msg);
    }

    // 20. Check for help request
    if (_isAskingForHelp(lowerMsg)) {
      return ChatbotResponse(message: _getHelpResponse(userName, lang));
    }

    // 21. Smart fallback with topic detection
    return ChatbotResponse(message: _getConversationalFallback(lowerMsg, userName, lang));
  }

  // ========== LANGUAGE DETECTION ==========

  /// Detect language from user message using word-level scoring.
  /// Returns 'en' for English, 'id' for Indonesian (default).
  String _detectLanguage(String msg) {
    // 1. Check for explicit "respond in English" requests
    final explicitEnglishPatterns = [
      'merespon menggunakan bahasa inggris',
      'merespon pakai bahasa inggris',
      'merespon dalam bahasa inggris',
      'jawab dalam bahasa inggris',
      'jawab pakai bahasa inggris',
      'respon bahasa inggris',
      'pakai bahasa inggris',
      'gunakan bahasa inggris',
      'respond in english',
      'reply in english',
      'answer in english',
      'use english',
      'in english please',
    ];
    for (final pattern in explicitEnglishPatterns) {
      if (msg.contains(pattern)) return 'en';
    }

    // 2. Word-level scoring: compare English vs Indonesian word counts
    final words = msg.split(RegExp(r'[\s,\.!?;:]+'));

    // English vocabulary (unambiguous English words)
    const englishWords = <String>{
      // Greetings
      'hello', 'hey', 'howdy', 'greetings', 'goodbye', 'bye',
      // Common verbs
      'open', 'show', 'check', 'view', 'close', 'find', 'get', 'see',
      'want', 'need', 'help', 'take', 'make', 'give', 'tell',
      'read', 'pay', 'send', 'cancel', 'delete', 'create', 'update',
      'know', 'like', 'ask', 'try', 'start', 'stop', 'call',
      // Politeness
      'please', 'thank', 'thanks', 'sorry', 'excuse',
      // Pronouns
      'my', 'me', 'you', 'your', 'we', 'our', 'they', 'their',
      'its', 'his', 'her',
      // Articles/prepositions/conjunctions
      'the', 'for', 'of', 'with', 'from', 'about', 'into',
      'between', 'after', 'before', 'during', 'until', 'since',
      'and', 'but', 'because', 'also', 'just', 'only',
      // Question words
      'what', 'when', 'where', 'how', 'why', 'which', 'who',
      // Auxiliary/modal verbs
      'is', 'are', 'am', 'was', 'were', 'do', 'does', 'did',
      'can', 'could', 'will', 'would', 'should', 'shall', 'might',
      'have', 'has', 'had',
      // Determiners
      'this', 'that', 'these', 'those', 'some', 'any', 'every', 'each',
      // Common adjectives/adverbs
      'all', 'next', 'last', 'new', 'old', 'much', 'many', 'more',
      'very', 'really', 'too', 'still', 'already', 'yet', 'again',
      'here', 'there', 'now', 'then', 'today', 'tomorrow', 'yesterday',
      // Negation
      'no', 'not',
      // Domain-specific nouns
      'bill', 'bills', 'invoice', 'invoices', 'payment', 'payments',
      'schedule', 'pickup', 'collection', 'waste', 'garbage', 'trash',
      'article', 'articles', 'report', 'reports', 'complaint', 'complaints',
      'history', 'service', 'services', 'account',
      'rubbish', 'fee', 'fees', 'amount', 'total', 'balance', 'due',
      // Navigation
      'app', 'page', 'screen', 'home', 'back', 'menu',
      // Misc
      'yes', 'okay', 'sure', 'right', 'well', 'let',
    };

    // Indonesian vocabulary (unambiguous Indonesian words)
    const indonesianWords = <String>{
      // Greetings
      'halo', 'hai', 'hei', 'assalamualaikum', 'salam',
      // Common verbs
      'buka', 'bukain', 'bukakan', 'tampilkan', 'tampilin',
      'lihat', 'liat', 'tutup', 'cari', 'ambil', 'kirim',
      'bayar', 'hapus', 'buat', 'baca', 'kasih', 'tolong',
      'bantu', 'tanya', 'minta', 'cek', 'periksa', 'arahkan',
      'arahin', 'pergi', 'pindah',
      // Pronouns
      'saya', 'aku', 'kamu', 'anda', 'dia', 'kita', 'kami', 'mereka',
      // Question words
      'apa', 'siapa', 'dimana', 'kapan', 'bagaimana', 'kenapa',
      'berapa', 'gimana', 'mana',
      // Domain-specific nouns
      'tagihan', 'jadwal', 'jemput', 'sampah', 'pengambilan',
      'penjemputan', 'pembayaran', 'riwayat', 'artikel', 'pelaporan',
      'laporan', 'lapor', 'keluhan', 'komplain', 'layanan', 'akun',
      'daftar',
      // Particles/conjunctions/prepositions
      'yang', 'dan', 'atau', 'ke', 'dari', 'untuk', 'dengan',
      'ini', 'itu', 'ya', 'tidak', 'bisa', 'mau', 'sudah', 'belum',
      'akan', 'sedang', 'juga', 'tapi', 'karena', 'kalau', 'jika',
      'nanti', 'dulu', 'dong', 'kok', 'sih', 'lah', 'kan', 'nih',
      'gak', 'gue', 'gw', 'lu', 'lo',
      // Time greetings
      'selamat', 'pagi', 'siang', 'sore', 'malam',
      // Politeness
      'terima', 'makasih', 'maaf', 'permisi',
      // Common adverbs/adjectives
      'semua', 'baru', 'lama', 'banyak', 'sedikit', 'lebih',
      'sangat', 'sekali', 'masih', 'lagi', 'deh',
      // Misc
      'bahasa', 'inggris', 'indonesia', 'menu', 'berupa',
    };

    int englishScore = 0;
    int indonesianScore = 0;

    for (final word in words) {
      final w = word.toLowerCase().trim();
      if (w.isEmpty) continue;
      if (englishWords.contains(w)) englishScore++;
      if (indonesianWords.contains(w)) indonesianScore++;
    }

    // 3. Multi-word phrase boosting for extra accuracy
    const englishPhrases = [
      'how are you', 'how much', 'how many', 'can you', 'could you',
      'i want', 'i need', 'show me', 'tell me', 'check my',
      'open the', 'go to', 'take me', 'let me',
      'good morning', 'good afternoon', 'good evening', 'good night',
      'my bill', 'my schedule', 'pickup schedule', 'payment history',
      'what is', 'where is', 'when is', 'how to',
      'create account', 'add account', 'service account', 'new account',
      'register account', 'sign up', 'set up account',
    ];
    for (final phrase in englishPhrases) {
      if (msg.contains(phrase)) englishScore += 2;
    }

    const indonesianPhrases = [
      'apa kabar', 'terima kasih', 'selamat pagi', 'selamat siang',
      'selamat sore', 'selamat malam', 'berapa tagihan', 'jadwal jemput',
      'tolong buka', 'mau lihat', 'bisa bantu', 'kapan jadwal',
      'cek tagihan', 'buka artikel', 'buka riwayat',
      'buat akun', 'tambah akun', 'daftar akun', 'akun layanan',
      'buat layanan', 'tambah layanan', 'daftar layanan',
    ];
    for (final phrase in indonesianPhrases) {
      if (msg.contains(phrase)) indonesianScore += 2;
    }

    // Return English if English score is higher
    if (englishScore > indonesianScore) return 'en';

    // Default to Indonesian
    return 'id';
  }

  // ========== LANGUAGE QUERY ==========

  /// Only trigger for PURE language queries (messages solely about switching language).
  /// If the message combines a language request with another intent (navigation, bills, etc.),
  /// we should process the actual intent instead and just use the detected language.
  bool _isLanguageQuery(String msg) {
    final hasLanguageMention = msg.contains('bahasa inggris') || msg.contains('bahasa indonesia') ||
           msg.contains('speak english') || msg.contains('in english') ||
           msg.contains('use english') || msg.contains('switch language') ||
           msg.contains('switch to english') || msg.contains('switch to indonesian') ||
           msg.contains('ganti bahasa') || msg.contains('pakai bahasa');

    if (!hasLanguageMention) return false;

    // If the message also has navigation, bill, or schedule intent,
    // don't treat it as a pure language query — let the actual intent handler process it
    if (_isNavigationQuery(msg) || _isBillQuery(msg) || _isScheduleQuery(msg)) {
      return false;
    }

    return true;
  }

  String _getLanguageResponse(String msg, String? userName, String lang) {
    final name = userName ?? 'Kak';
    if (msg.contains('bahasa inggris') || msg.contains('english') || msg.contains('speak english')) {
      return "Of course, $name! 🌍\n\n"
             "I can speak both **Indonesian** and **English**! 😊\n\n"
             "Just type your message in English, and I'll reply in English too.\n\n"
             "Here's what I can help you with:\n"
             "💰 Check your **bills** → type \"check my bill\"\n"
             "📅 View **pickup schedule** → type \"my schedule\"\n"
             "📱 Open **app menus** → type \"open articles\", \"open payment history\"\n\n"
             "How can I help you today? 😊";
    } else {
      return "Tentu, $name! 🇮🇩\n\n"
             "Aku bisa berbicara dalam **Bahasa Indonesia** dan **Bahasa Inggris**! 😊\n\n"
             "Cukup ketik pesan dalam bahasa yang kamu mau, dan aku akan membalas dengan bahasa yang sama.\n\n"
             "Berikut yang bisa aku bantu:\n"
             "💰 Cek **tagihan** → ketik \"berapa tagihan saya\"\n"
             "📅 Lihat **jadwal jemput** → ketik \"jadwal jemput sampah\"\n"
             "📱 Buka **menu layanan** → ketik \"buka artikel\", \"buka riwayat pembayaran\"\n\n"
             "Ada yang bisa aku bantu? 😊";
    }
  }

  // ========== GREETING DETECTION ==========
  
  bool _isGreetingWithAI(String msg) {
    return (msg.contains('smart ai') || msg.contains('smartai') || msg.contains('smart-ai')) &&
           (msg.contains('hai') || msg.contains('hi') || msg.contains('halo') || 
            msg.contains('hello') || msg.contains('hey'));
  }

  bool _isSimpleGreeting(String msg) {
    final greetings = [
      // Indonesian
      'halo', 'hai', 'hei', 'selamat pagi', 'selamat siang', 'selamat sore', 
      'selamat malam', 'assalamualaikum', 'salam',
      // English
      'hi', 'hello', 'hey', 'good morning', 'good afternoon', 'good evening', 
      'good night', 'howdy', 'greetings',
    ];
    return greetings.any((g) => msg.contains(g));
  }

  bool _isAskingHowAreYou(String msg) {
    return msg.contains('apa kabar') || msg.contains('kabar') || 
           msg.contains('how are you') || msg.contains('how r u') ||
           msg.contains('how do you do') || msg.contains('how\'s it going') ||
           msg.contains('gimana') || (msg.contains('baik') && msg.contains('kamu'));
  }

  bool _isThankYou(String msg) {
    return msg.contains('terima kasih') || msg.contains('makasih') || 
           msg.contains('thanks') || msg.contains('thank you') ||
           msg.contains('thx') || msg.contains('tq') ||
           msg.contains('thankyou') || msg.contains('appreciated');
  }

  /// Detects intent to PAY a bill (not just check it)
  bool _isPayBillQuery(String msg) {
    // Explicit pay intent patterns
    final payPatterns = [
      // Indonesian
      'bayar tagihan', 'bayarkan tagihan', 'bayarin tagihan',
      'mau bayar', 'ingin bayar', 'tolong bayar', 'bantu bayar',
      'proses bayar', 'lakukan pembayaran', 'bayar sekarang',
      'bayar semua', 'bayar bill', 'bayar invoice',
      'lunasi tagihan', 'lunasi', 'bayar hutang',
      'bayar tunggakan', 'bayar iuran',
      // English
      'pay my bill', 'pay the bill', 'pay my invoice',
      'pay bill', 'pay invoice', 'make payment',
      'make a payment', 'process payment', 'pay now',
      'can you pay', 'please pay', 'help me pay',
      'want to pay', 'like to pay', 'need to pay',
      'pay all', 'settle my bill', 'settle bill',
      'pay off', 'clear my bill', 'pay for',
    ];
    return payPatterns.any((p) => msg.contains(p));
  }

  bool _isBillQuery(String msg) {
    return msg.contains('tagihan') || msg.contains('bill') || 
           msg.contains('invoice') || msg.contains('bayar') ||
           msg.contains('pay') || (msg.contains('berapa') && msg.contains('tagihan')) ||
           msg.contains('cek tagihan') || msg.contains('hutang') ||
           msg.contains('tunggakan') || msg.contains('belum bayar') ||
           msg.contains('berapa yang harus') || msg.contains('total bayar') ||
           msg.contains('check my bill') || msg.contains('how much') ||
           msg.contains('my bill') || msg.contains('unpaid') ||
           msg.contains('outstanding') || msg.contains('amount due') ||
           msg.contains('payment due') || msg.contains('owe');
  }

  bool _isScheduleQuery(String msg) {
    return msg.contains('jadwal') || msg.contains('kapan') || 
           msg.contains('pickup') || msg.contains('jemput') ||
           msg.contains('schedule') || msg.contains('pengambilan') ||
           msg.contains('diambil') || msg.contains('sampah diangkut') ||
           msg.contains('collection') || msg.contains('when is') ||
           msg.contains('next pickup') || msg.contains('pickup time') ||
           msg.contains('waste collection') || msg.contains('my schedule');
  }

  bool _isAskingForHelp(String msg) {
    return msg.contains('bantuan') || msg.contains('help') ||
           msg.contains('bisa apa') || msg.contains('fitur') ||
           msg.contains('apa saja') || msg.contains('what can you do') ||
           msg.contains('what can you help') || msg.contains('features') ||
           msg.contains('assist') || msg.contains('kemampuan');
  }

  // ========== NAVIGATION DETECTION ==========

  bool _isNavigationQuery(String msg) {
    final navigationKeywords = [
      // Indonesian
      'buka', 'bukain', 'bukakan', 'tolong buka',
      'tampilkan', 'tampilin',
      'lihat', 'liat', 'mau lihat', 'mau liat',
      'ke halaman', 'ke menu', 'ke bagian',
      'halaman', 'arahkan', 'arahin',
      'pergi ke', 'pindah ke',
      'carikan', 'cari menu', 'akses',
      // English
      'open', 'show me', 'go to', 'navigate to', 'take me to',
      'bring me to', 'access', 'view the', 'open the',
      'show the', 'display', 'direct me',
    ];

    final menuKeywords = [
      // Indonesian
      'jadwal', 'pengambilan', 'request', 'riwayat', 'pembayaran',
      'artikel', 'pelaporan', 'lapor', 'laporan',
      'layanan', 'daftar layanan', 'menu',
      'tagihan', 'bayar', 'invoice', 'express', 'jemput',
      'akun layanan', 'tambah akun',
      // English
      'schedule', 'pickup', 'collection', 'history', 'payment',
      'article', 'report', 'complaint', 'service', 'billing',
      'service account', 'add account',
    ];

    final hasNavIntent = navigationKeywords.any((k) => msg.contains(k));
    final hasMenuTarget = menuKeywords.any((k) => msg.contains(k));

    return hasNavIntent && hasMenuTarget;
  }

  ChatbotResponse _handleNavigationQuery(String msg, String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    List<ChatbotNavAction> actions = [];
    List<String> menuNames = [];

    if (_matchesJadwalPengambilan(msg)) {
      actions.add(const ChatbotNavAction(
        route: 'jadwal_pengambilan', label: 'Jadwal Pengambilan', icon: 'calendar_today',
      ));
      menuNames.add(lang == 'en' ? 'Pickup Schedule' : 'Jadwal Pengambilan');
    }

    if (_matchesRequestPengambilan(msg)) {
      actions.add(const ChatbotNavAction(
        route: 'request_pengambilan', label: 'Request Pengambilan', icon: 'local_shipping',
      ));
      menuNames.add(lang == 'en' ? 'Pickup Request' : 'Request Pengambilan');
    }

    if (_matchesRiwayatPengambilan(msg)) {
      actions.add(const ChatbotNavAction(
        route: 'riwayat_pengambilan', label: 'Riwayat Pengambilan', icon: 'history',
      ));
      menuNames.add(lang == 'en' ? 'Pickup History' : 'Riwayat Pengambilan');
    }

    if (_matchesRiwayatPembayaran(msg)) {
      actions.add(const ChatbotNavAction(
        route: 'riwayat_pembayaran', label: 'Riwayat Pembayaran', icon: 'receipt_long',
      ));
      menuNames.add(lang == 'en' ? 'Payment History' : 'Riwayat Pembayaran');
    }

    if (_matchesArtikel(msg)) {
      actions.add(const ChatbotNavAction(
        route: 'artikel', label: 'Artikel', icon: 'article',
      ));
      menuNames.add(lang == 'en' ? 'Articles' : 'Artikel');
    }

    if (_matchesPelaporan(msg)) {
      actions.add(const ChatbotNavAction(
        route: 'pelaporan', label: 'Pelaporan', icon: 'report_problem',
      ));
      menuNames.add(lang == 'en' ? 'Reports' : 'Pelaporan');
    }

    if (_matchesTambahAkunLayanan(msg)) {
      actions.add(const ChatbotNavAction(
        route: 'tambah_akun_layanan', label: 'Tambah Akun Layanan', icon: 'person_add',
      ));
      menuNames.add(lang == 'en' ? 'Add Service Account' : 'Tambah Akun Layanan');
    }

    // All services list
    if (actions.isEmpty && (msg.contains('daftar layanan') || msg.contains('semua menu') || 
        msg.contains('semua layanan') || msg.contains('all services') || 
        msg.contains('all menus') || msg.contains('service list'))) {
      actions = _getAllNavActions();
      return ChatbotResponse(
        message: lang == 'en'
          ? "Sure, $name! 😊\n\nHere are all available services in the app. Tap any button below to open it:"
          : "Tentu, $name! 😊\n\nBerikut daftar layanan yang tersedia di aplikasi. Kamu bisa langsung tap tombol di bawah untuk membukanya:",
        actions: actions,
      );
    }

    // No specific match
    if (actions.isEmpty) {
      actions = _getAllNavActions();
      return ChatbotResponse(
        message: lang == 'en'
          ? "Hmm, I'm not sure which menu you mean, $name 🤔\n\nHere are all available services. Please choose one:"
          : "Hmm, aku belum yakin menu mana yang kamu maksud, $name 🤔\n\nIni daftar semua layanan yang tersedia. Silakan pilih yang kamu butuhkan:",
        actions: actions,
      );
    }

    // Single match - auto navigate
    if (actions.length == 1) {
      return ChatbotResponse(
        message: lang == 'en'
          ? "Sure thing, $name! 👍\n\nOpening **${menuNames.first}** for you now..."
          : "Siap, $name! 👍\n\nAku bukakan **${menuNames.first}** untuk kamu sekarang...",
        actions: actions,
        autoNavigate: true,
      );
    }

    // Multiple match
    return ChatbotResponse(
      message: lang == 'en'
        ? "Alright $name! 😊\n\nI found several matching menus. Please choose the one you need:"
        : "Oke $name! 😊\n\nAku temukan beberapa menu yang cocok. Silakan pilih yang kamu butuhkan:",
      actions: actions,
    );
  }

  List<ChatbotNavAction> _getAllNavActions() {
    return [
      const ChatbotNavAction(route: 'jadwal_pengambilan', label: 'Jadwal Pengambilan', icon: 'calendar_today'),
      const ChatbotNavAction(route: 'request_pengambilan', label: 'Request Pengambilan', icon: 'local_shipping'),
      const ChatbotNavAction(route: 'riwayat_pengambilan', label: 'Riwayat Pengambilan', icon: 'history'),
      const ChatbotNavAction(route: 'riwayat_pembayaran', label: 'Riwayat Pembayaran', icon: 'receipt_long'),
      const ChatbotNavAction(route: 'artikel', label: 'Artikel', icon: 'article'),
      const ChatbotNavAction(route: 'pelaporan', label: 'Pelaporan', icon: 'report_problem'),
      const ChatbotNavAction(route: 'tambah_akun_layanan', label: 'Tambah Akun Layanan', icon: 'person_add'),
    ];
  }

  // ========== MENU MATCHING HELPERS ==========

  bool _matchesJadwalPengambilan(String msg) {
    return (msg.contains('jadwal') && (msg.contains('pengambilan') || msg.contains('jemput') || msg.contains('ambil'))) ||
           (msg.contains('jadwal') && !msg.contains('riwayat') && !msg.contains('pembayaran')) ||
           (msg.contains('schedule') && (msg.contains('pickup') || msg.contains('collection'))) ||
           (msg.contains('pickup') && msg.contains('schedule'));
  }

  bool _matchesRequestPengambilan(String msg) {
    return (msg.contains('request') && (msg.contains('pengambilan') || msg.contains('jemput') || msg.contains('ambil') || msg.contains('pickup'))) ||
           msg.contains('express') ||
           (msg.contains('minta') && msg.contains('jemput')) ||
           (msg.contains('request') && msg.contains('collection'));
  }

  bool _matchesRiwayatPengambilan(String msg) {
    return (msg.contains('riwayat') && (msg.contains('pengambilan') || msg.contains('jemput') || msg.contains('ambil'))) ||
           (msg.contains('history') && (msg.contains('pickup') || msg.contains('collection'))) ||
           (msg.contains('pickup') && msg.contains('history'));
  }

  bool _matchesRiwayatPembayaran(String msg) {
    return (msg.contains('riwayat') && (msg.contains('pembayaran') || msg.contains('bayar') || msg.contains('transaksi'))) ||
           (msg.contains('history') && (msg.contains('payment') || msg.contains('bayar'))) ||
           (msg.contains('riwayat') && msg.contains('tagihan')) ||
           (msg.contains('payment') && msg.contains('history')) ||
           (msg.contains('transaction') && msg.contains('history'));
  }

  bool _matchesArtikel(String msg) {
    return msg.contains('artikel') || msg.contains('berita') || msg.contains('article') ||
           msg.contains('articles') || msg.contains('news') ||
           (msg.contains('baca') && (msg.contains('info') || msg.contains('artikel'))) ||
           (msg.contains('read') && (msg.contains('article') || msg.contains('news')));
  }

  bool _matchesPelaporan(String msg) {
    return msg.contains('pelaporan') || msg.contains('lapor') || msg.contains('laporan') ||
           msg.contains('keluhan') || msg.contains('komplain') || msg.contains('report') ||
           msg.contains('complaint') || msg.contains('complain');
  }

  bool _matchesTambahAkunLayanan(String msg) {
    return (msg.contains('tambah') && msg.contains('akun')) ||
           (msg.contains('buat') && msg.contains('akun')) ||
           (msg.contains('daftar') && msg.contains('akun')) ||
           (msg.contains('add') && msg.contains('account')) ||
           (msg.contains('create') && msg.contains('account')) ||
           (msg.contains('new') && msg.contains('account')) ||
           (msg.contains('register') && msg.contains('account')) ||
           (msg.contains('tambah') && msg.contains('layanan')) ||
           (msg.contains('daftar') && msg.contains('layanan')) ||
           (msg.contains('add') && msg.contains('service')) ||
           (msg.contains('create') && msg.contains('service')) ||
           (msg.contains('new') && msg.contains('service')) ||
           (msg.contains('register') && msg.contains('service'));
  }

  // ========== CREATE SERVICE ACCOUNT INTENT ==========

  /// Detects intent to create/add a service account.
  /// This is given highest priority because it is an action-oriented command.
  bool _isCreateServiceAccountQuery(String msg) {
    final createPatterns = [
      // Indonesian
      'buat akun layanan', 'buatkan akun layanan', 'bikin akun layanan',
      'tambah akun layanan', 'tambahkan akun layanan', 'tambahin akun layanan',
      'daftar akun layanan', 'daftarkan akun layanan',
      'buat akun baru', 'tambah akun baru', 'bikin akun baru',
      'mau buat akun', 'mau tambah akun', 'mau daftar akun',
      'ingin buat akun', 'ingin tambah akun', 'ingin daftar akun',
      'tolong buat akun', 'tolong tambah akun', 'tolong daftar akun',
      'bantu buat akun', 'bantu tambah akun', 'bantu daftar akun',
      'buat layanan', 'tambah layanan', 'daftar layanan baru',
      'buat layanan baru', 'tambah layanan baru', 'bikin layanan baru',
      'mau buat layanan', 'mau tambah layanan', 'mau daftar layanan',
      'daftarkan layanan', 'daftarin layanan',
      'buat akun sampah', 'daftar akun sampah', 'tambah akun sampah',
      'registrasi akun', 'registrasi layanan',
      // English
      'create service account', 'add service account', 'new service account',
      'create account', 'add account', 'new account',
      'register service account', 'register account',
      'make service account', 'make account', 'make new account',
      'set up account', 'setup account', 'set up service',
      'i want to create account', 'i want to add account',
      'i need an account', 'i need a service account',
      'help me create account', 'help me add account',
      'create my account', 'add my account', 'register my account',
      'sign up for service', 'sign up account',
      'create a new service', 'add a new service',
      'create waste account', 'add waste account',
    ];
    return createPatterns.any((p) => msg.contains(p));
  }

  ChatbotResponse _handleCreateServiceAccountQuery(String msg, String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    // Start the conversational flow
    _saStep = 'askName';
    _saLang = lang;
    _saUserName = userName;
    // Pre-load kecamatan options in background
    _preloadKecamatanOptions();

    if (lang == 'en') {
      return ChatbotResponse(
        message: "Sure, $name! 🎉 I'll help you create a new **service account** right here in the chat!\n\n"
            "I'll ask you a few questions to fill in the data. You can type **\"cancel\"** anytime to stop.\n\n"
            "Let's start! 📝\n\n"
            "**What is the full name for this account?**",
      );
    }

    return ChatbotResponse(
      message: "Siap, $name! 🎉 Aku akan bantu buatkan **akun layanan** baru langsung di sini!\n\n"
          "Aku akan tanya beberapa data yang diperlukan. Kamu bisa ketik **\"batal\"** kapan saja untuk membatalkan.\n\n"
          "Yuk mulai! 📝\n\n"
          "**Siapa nama lengkap untuk akun ini?**",
    );
  }

  Future<void> _preloadKecamatanOptions() async {
    try {
      _saKecamatanOptions = await _areaService.fetchKecamatan();
      final settings = await _configService.fetchAppSettings();
      _saCityName = settings?.city?.name;
      _saProvinceName = settings?.province?.name;
    } catch (e) {
      debugPrint('[ChatbotService] Failed to preload kecamatan: $e');
    }
  }

  bool _isCancelIntent(String msg) {
    return msg == 'batal' || msg == 'cancel' || msg == 'batalkan' ||
           msg.contains('batal') || msg.contains('cancel') ||
           msg == 'stop' || msg == 'quit' || msg == 'keluar' ||
           msg == 'tidak jadi' || msg == 'ga jadi' || msg == 'gak jadi';
  }

  Future<ChatbotResponse> _handleServiceAccountStep(String lowerMsg, String originalMsg, String? userName) async {
    final lang = _saLang;
    final name = userName ?? _saUserName ?? (lang == 'en' ? 'there' : 'Kak');

    switch (_saStep) {
      case 'askName':
        return _stepCollectName(originalMsg.trim(), name, lang);
      case 'askPhone':
        return _stepCollectPhone(originalMsg.trim(), name, lang);
      case 'askKecamatan':
        return await _stepCollectKecamatan(originalMsg.trim(), name, lang);
      case 'askKelurahan':
        return await _stepCollectKelurahan(originalMsg.trim(), name, lang);
      case 'askRW':
        return _stepCollectRW(originalMsg.trim(), name, lang);
      case 'askAddress':
        return _stepCollectAddress(originalMsg.trim(), name, lang);
      case 'confirm':
        return await _stepConfirm(lowerMsg, name, lang);
      default:
        _resetServiceAccountFlow();
        return ChatbotResponse(message: lang == 'en'
            ? "Something went wrong. Let's start over! 😅"
            : "Ada yang salah. Yuk mulai ulang! 😅");
    }
  }

  // --- Step 1: Collect Name ---
  ChatbotResponse _stepCollectName(String input, String name, String lang) {
    if (input.isEmpty || input.length < 2) {
      return ChatbotResponse(message: lang == 'en'
          ? "The name seems too short. Please enter a **full name** (at least 2 characters):"
          : "Nama terlalu pendek. Silakan masukkan **nama lengkap** (minimal 2 karakter):");
    }
    _saData['name'] = input;
    _saStep = 'askPhone';
    return ChatbotResponse(
      message: lang == 'en'
          ? "Got it! Name: **$input** ✅\n\nNow, what is the **phone number**?\n_(Must start with 08, e.g. 081234567890)_"
          : "Oke! Nama: **$input** ✅\n\nSekarang, berapa **nomor telepon** nya?\n_(Harus dimulai dengan 08, contoh: 081234567890)_",
    );
  }

  // --- Step 2: Collect Phone ---
  ChatbotResponse _stepCollectPhone(String input, String name, String lang) {
    final phone = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (!phone.startsWith('08') || phone.length < 11 || phone.length > 13) {
      return ChatbotResponse(message: lang == 'en'
          ? "⚠️ Invalid phone number. It must:\n• Start with **08**\n• Be **11-13 digits** long\n\nPlease try again:"
          : "⚠️ Nomor telepon tidak valid. Syarat:\n• Dimulai dengan **08**\n• Panjang **11-13 digit**\n\nCoba masukkan lagi:");
    }
    _saData['phone'] = phone;
    _saStep = 'askKecamatan';

    // Show available kecamatan options
    String optionsText = '';
    if (_saKecamatanOptions.isNotEmpty) {
      final names = _saKecamatanOptions.map((o) => o.name).take(15).toList();
      optionsText = lang == 'en'
          ? "\n\n📍 Available districts:\n${names.map((n) => '• $n').join('\n')}"
          : "\n\n📍 Kecamatan yang tersedia:\n${names.map((n) => '• $n').join('\n')}";
      if (_saKecamatanOptions.length > 15) {
        optionsText += lang == 'en' ? '\n_(and more...)_' : '\n_(dan lainnya...)_';
      }
    }

    return ChatbotResponse(
      message: lang == 'en'
          ? "Phone: **$phone** ✅\n\nNext, what **district (kecamatan)** are you in?$optionsText\n\n_Type the district name:_"
          : "Telepon: **$phone** ✅\n\nSelanjutnya, **kecamatan** mana?$optionsText\n\n_Ketik nama kecamatan:_",
    );
  }

  // --- Step 3: Collect Kecamatan ---
  Future<ChatbotResponse> _stepCollectKecamatan(String input, String name, String lang) async {
    if (_saKecamatanOptions.isEmpty) {
      try { _saKecamatanOptions = await _areaService.fetchKecamatan(); } catch (_) {}
    }

    final match = _findAreaFuzzy(_saKecamatanOptions, input);
    if (match == null) {
      String suggestion = '';
      if (_saKecamatanOptions.isNotEmpty) {
        final similar = _saKecamatanOptions
            .where((o) => o.name.toLowerCase().contains(input.toLowerCase().substring(0, (input.length * 0.5).ceil().clamp(1, input.length))))
            .take(5).map((o) => '• ${o.name}').toList();
        if (similar.isNotEmpty) {
          suggestion = lang == 'en'
              ? "\n\nDid you mean one of these?\n${similar.join('\n')}"
              : "\n\nMungkin maksud kamu salah satu ini?\n${similar.join('\n')}";
        }
      }
      return ChatbotResponse(message: lang == 'en'
          ? "⚠️ District **\"$input\"** not found.$suggestion\n\nPlease type a valid district name:"
          : "⚠️ Kecamatan **\"$input\"** tidak ditemukan.$suggestion\n\nSilakan ketik nama kecamatan yang valid:");
    }

    _saSelectedKecamatan = match;
    _saData['kecamatan'] = match.name;
    _saStep = 'askKelurahan';

    // Load kelurahan options
    try {
      _saKelurahanOptions = await _areaService.fetchKelurahan(parentId: match.id);
    } catch (_) {
      _saKelurahanOptions = [];
    }

    String optionsText = '';
    if (_saKelurahanOptions.isNotEmpty) {
      final names = _saKelurahanOptions.map((o) => o.name).toList();
      optionsText = lang == 'en'
          ? "\n\n📍 Available sub-districts:\n${names.map((n) => '• $n').join('\n')}"
          : "\n\n📍 Kelurahan yang tersedia:\n${names.map((n) => '• $n').join('\n')}";
    }

    return ChatbotResponse(
      message: lang == 'en'
          ? "District: **${match.name}** ✅\n\nNow, which **sub-district (kelurahan)**?$optionsText\n\n_Type the sub-district name:_"
          : "Kecamatan: **${match.name}** ✅\n\nSekarang, **kelurahan** mana?$optionsText\n\n_Ketik nama kelurahan:_",
    );
  }

  // --- Step 4: Collect Kelurahan ---
  Future<ChatbotResponse> _stepCollectKelurahan(String input, String name, String lang) async {
    final match = _findAreaFuzzy(_saKelurahanOptions, input);
    if (match == null) {
      String suggestion = '';
      if (_saKelurahanOptions.isNotEmpty) {
        final names = _saKelurahanOptions.map((o) => '• ${o.name}').toList();
        suggestion = lang == 'en'
            ? "\n\nAvailable options:\n${names.join('\n')}"
            : "\n\nPilihan yang tersedia:\n${names.join('\n')}";
      }
      return ChatbotResponse(message: lang == 'en'
          ? "⚠️ Sub-district **\"$input\"** not found.$suggestion\n\nPlease type a valid sub-district name:"
          : "⚠️ Kelurahan **\"$input\"** tidak ditemukan.$suggestion\n\nSilakan ketik nama kelurahan yang valid:");
    }

    _saSelectedKelurahan = match;
    _saData['kelurahan'] = match.name;
    _saStep = 'askRW';

    return ChatbotResponse(
      message: lang == 'en'
          ? "Sub-district: **${match.name}** ✅\n\nWhat is your **RW (neighborhood unit)** number?\n_(e.g. RW 01, RW 05)_"
          : "Kelurahan: **${match.name}** ✅\n\nBerapa nomor **RW (Rukun Warga)** kamu?\n_(contoh: RW 01, RW 05)_",
    );
  }

  // --- Step 5: Collect RW ---
  ChatbotResponse _stepCollectRW(String input, String name, String lang) {
    String rw = input.toUpperCase().trim();
    if (!rw.startsWith('RW')) rw = 'RW $rw';
    final rwNum = int.tryParse(rw.replaceAll(RegExp(r'[^0-9]'), ''));
    if (rwNum == null || rwNum == 0) {
      return ChatbotResponse(message: lang == 'en'
          ? "⚠️ Invalid RW. It must be at least **RW 01** (not RW 00).\n\nPlease try again:"
          : "⚠️ RW tidak valid. Minimal **RW 01** (tidak boleh RW 00).\n\nCoba masukkan lagi:");
    }
    final formattedRW = 'RW ${rwNum.toString().padLeft(3, '0')}';
    _saData['rw'] = formattedRW;
    _saStep = 'askAddress';

    return ChatbotResponse(
      message: lang == 'en'
          ? "RW: **$formattedRW** ✅\n\nLastly, please provide the **address details**.\n_(e.g. Jl. Merpati No. 5, RT 03)_"
          : "RW: **$formattedRW** ✅\n\nTerakhir, masukkan **detail alamat**.\n_(contoh: Jl. Merpati No. 5, RT 03)_",
    );
  }

  // --- Step 6: Collect Address ---
  ChatbotResponse _stepCollectAddress(String input, String name, String lang) {
    if (input.length < 5) {
      return ChatbotResponse(message: lang == 'en'
          ? "Address is too short. Please provide more details (at least 5 characters):"
          : "Alamat terlalu pendek. Silakan berikan detail lebih lengkap (minimal 5 karakter):");
    }
    _saData['address'] = input;
    _saStep = 'confirm';

    // Build confirmation summary
    final summary = lang == 'en'
        ? "📋 **Account Summary:**\n\n"
          "👤 **Name:** ${_saData['name']}\n"
          "📞 **Phone:** ${_saData['phone']}\n"
          "📍 **District:** ${_saData['kecamatan']}\n"
          "🏘️ **Sub-district:** ${_saData['kelurahan']}\n"
          "🏠 **RW:** ${_saData['rw']}\n"
          "📫 **Address:** ${_saData['address']}\n\n"
          "Is this data correct? Type **\"yes\"** to create the account, or **\"no\"** to cancel."
        : "📋 **Ringkasan Data Akun:**\n\n"
          "👤 **Nama:** ${_saData['name']}\n"
          "📞 **Telepon:** ${_saData['phone']}\n"
          "📍 **Kecamatan:** ${_saData['kecamatan']}\n"
          "🏘️ **Kelurahan:** ${_saData['kelurahan']}\n"
          "🏠 **RW:** ${_saData['rw']}\n"
          "📫 **Alamat:** ${_saData['address']}\n\n"
          "Apakah data di atas sudah benar? Ketik **\"ya\"** untuk membuat akun, atau **\"tidak\"** untuk membatalkan.";

    return ChatbotResponse(message: summary);
  }

  // --- Step 7: Confirm & Create ---
  Future<ChatbotResponse> _stepConfirm(String lowerMsg, String name, String lang) async {
    final isYes = lowerMsg == 'ya' || lowerMsg == 'yes' || lowerMsg == 'y' ||
        lowerMsg == 'iya' || lowerMsg == 'yap' || lowerMsg == 'yep' ||
        lowerMsg == 'ok' || lowerMsg == 'oke' || lowerMsg == 'okay' ||
        lowerMsg == 'benar' || lowerMsg == 'betul' || lowerMsg == 'correct' ||
        lowerMsg == 'sure' || lowerMsg == 'confirm' || lowerMsg == 'konfirmasi' ||
        lowerMsg == 'siap' || lowerMsg == 'setuju' || lowerMsg == 'yoi' ||
        lowerMsg.contains('ya ') || lowerMsg.contains('yes') || lowerMsg.contains('buat');
    final isNo = lowerMsg == 'tidak' || lowerMsg == 'no' || lowerMsg == 'n' ||
        lowerMsg == 'nggak' || lowerMsg == 'gak' || lowerMsg == 'enggak' ||
        lowerMsg == 'jangan' || lowerMsg == 'salah' || lowerMsg == 'wrong';

    if (isNo) {
      _resetServiceAccountFlow();
      return ChatbotResponse(message: lang == 'en'
          ? "No problem, $name! 👍 Account creation cancelled.\n\nFeel free to try again anytime! 😊"
          : "Oke, $name! 👍 Pembuatan akun dibatalkan.\n\nKalau mau coba lagi, bilang aja ya! 😊");
    }

    if (!isYes) {
      return ChatbotResponse(message: lang == 'en'
          ? "Please type **\"yes\"** to confirm, or **\"no\"** to cancel. 🤔"
          : "Silakan ketik **\"ya\"** untuk konfirmasi, atau **\"tidak\"** untuk membatalkan. 🤔");
    }

    // Execute account creation!
    try {
      // Geocode address for lat/lng
      double lat = -6.2;
      double lng = 106.8;
      try {
        final coords = await _geocodeAddress(
          '${_saData['address']}, ${_saData['kelurahan']}, ${_saData['kecamatan']}, ${_saCityName ?? ''}');
        if (coords != null) { lat = coords[0]; lng = coords[1]; }
      } catch (_) {}

      final account = await _serviceAccountService.createAccount(
        name: _saData['name']!,
        contactPhone: _saData['phone'],
        address: _saData['address']!,
        areaId: _saSelectedKelurahan!.id,
        rwName: _saData['rw'],
        latitude: lat,
        longitude: lng,
      );

      _resetServiceAccountFlow();

      return ChatbotResponse(
        message: lang == 'en'
            ? "🎉 **Account created successfully!**\n\n"
              "✅ **${account.name}** has been registered!\n\n"
              "📋 Account Details:\n"
              "• ID: ${account.id}\n"
              "• Phone: ${account.contactPhone ?? '-'}\n"
              "• Area: ${account.kelurahanName ?? ''}, ${account.kecamatanName ?? ''}\n"
              "• RW: ${account.rwName ?? '-'}\n\n"
              "Your account is now active! Is there anything else I can help you with? 😊"
            : "🎉 **Akun layanan berhasil dibuat!**\n\n"
              "✅ **${account.name}** sudah terdaftar!\n\n"
              "📋 Detail Akun:\n"
              "• ID: ${account.id}\n"
              "• Telepon: ${account.contactPhone ?? '-'}\n"
              "• Area: ${account.kelurahanName ?? ''}, ${account.kecamatanName ?? ''}\n"
              "• RW: ${account.rwName ?? '-'}\n\n"
              "Akun kamu sudah aktif! Ada lagi yang bisa aku bantu? 😊",
      );
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      _resetServiceAccountFlow();
      return ChatbotResponse(
        message: lang == 'en'
            ? "❌ Sorry $name, failed to create account: $errorMsg\n\nPlease try again or use the form manually. 😅"
            : "❌ Maaf $name, gagal membuat akun: $errorMsg\n\nSilakan coba lagi atau buat lewat form manual. 😅",
        actions: [
          const ChatbotNavAction(route: 'tambah_akun_layanan', label: 'Buka Form Manual', icon: 'person_add'),
        ],
      );
    }
  }

  // --- Fuzzy area matching ---
  AreaOption? _findAreaFuzzy(List<AreaOption> options, String input) {
    if (options.isEmpty || input.isEmpty) return null;
    final query = input.toLowerCase().trim()
        .replaceAll(RegExp(r'^kecamatan\s+', caseSensitive: false), '')
        .replaceAll(RegExp(r'^kelurahan\s+', caseSensitive: false), '')
        .trim();
    // Exact match
    for (final o in options) {
      if (o.name.toLowerCase() == query) return o;
    }
    // Contains match
    for (final o in options) {
      final n = o.name.toLowerCase();
      if (n.contains(query) || query.contains(n)) return o;
    }
    // Partial word match
    if (query.length >= 3) {
      for (final o in options) {
        if (o.name.toLowerCase().contains(query.substring(0, 3))) return o;
      }
    }
    return null;
  }

  // --- Geocode address to lat/lng using Nominatim ---
  Future<List<double>?> _geocodeAddress(String address) async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: 'https://nominatim.openstreetmap.org',
        headers: {'User-Agent': 'smart-environment-mobile/1.0', 'Accept': 'application/json'},
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final response = await dio.get<List<dynamic>>(
        '/search', queryParameters: {'format': 'json', 'limit': 1, 'q': address},
      );
      final data = response.data;
      if (data != null && data.isNotEmpty && data.first is Map<String, dynamic>) {
        final lat = double.tryParse(data.first['lat']?.toString() ?? '');
        final lng = double.tryParse(data.first['lon']?.toString() ?? '');
        if (lat != null && lng != null) return [lat, lng];
      }
    } catch (e) {
      debugPrint('[ChatbotService] Geocode error: $e');
    }
    return null;
  }


  // ========== GREETING RESPONSES ==========

  String _getPersonalGreeting(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    final hour = DateTime.now().hour;
    
    if (lang == 'en') {
      String timeGreeting;
      if (hour < 11) {
        timeGreeting = 'Good morning';
      } else if (hour < 15) {
        timeGreeting = 'Good afternoon';
      } else if (hour < 18) {
        timeGreeting = 'Good evening';
      } else {
        timeGreeting = 'Good night';
      }
      return "Hi $name! 👋 $timeGreeting!\n\n"
             "How are you today? Great to chat with you! 😊\n\n"
             "How can I help? Want to check your bills or waste pickup schedule?";
    }

    String timeGreeting;
    if (hour < 11) {
      timeGreeting = 'Selamat pagi';
    } else if (hour < 15) {
      timeGreeting = 'Selamat siang';
    } else if (hour < 18) {
      timeGreeting = 'Selamat sore';
    } else {
      timeGreeting = 'Selamat malam';
    }
    return "Hai $name! 👋 $timeGreeting!\n\n"
           "Apa kabar hari ini? Senang bisa ngobrol sama kamu! 😊\n\n"
           "Gimana, ada yang bisa aku bantu? Mau cek tagihan atau jadwal jemput sampah?";
  }

  String _getSimpleGreetingResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    final hour = DateTime.now().hour;
    
    if (lang == 'en') {
      String timeGreeting;
      if (hour < 11) {
        timeGreeting = 'What a bright morning';
      } else if (hour < 15) {
        timeGreeting = 'Hope you\'re having a great afternoon';
      } else if (hour < 18) {
        timeGreeting = 'What a lovely evening';
      } else {
        timeGreeting = 'Hope you\'re having a good night';
      }
      return "Hi $name! 😊 $timeGreeting!\n\n"
             "I'm Smart AI, your virtual assistant for waste management. "
             "How can I help you today?\n\n"
             "💡 *Try asking:*\n"
             "• \"How much is my bill?\"\n"
             "• \"When is my next waste pickup?\"";
    }

    String timeGreeting;
    if (hour < 11) {
      timeGreeting = 'Pagi yang cerah';
    } else if (hour < 15) {
      timeGreeting = 'Siang yang produktif';
    } else if (hour < 18) {
      timeGreeting = 'Sore yang menyenangkan';
    } else {
      timeGreeting = 'Malam yang nyaman';
    }
    return "Hai $name! 😊 $timeGreeting ya!\n\n"
           "Aku Smart AI, asisten virtual kamu untuk pengelolaan sampah. "
           "Ada yang bisa aku bantu hari ini?\n\n"
           "💡 *Coba tanya:*\n"
           "• \"Berapa tagihan saya?\"\n"
           "• \"Kapan jadwal jemput sampah?\"";
  }

  String _getHowAreYouResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    if (lang == 'en') {
      return "I'm doing great, $name! Thanks for asking 🥰\n\n"
             "Always ready 24/7 to help you! How are you doing today?\n\n"
             "By the way, do you have any questions about waste management or bills?";
    }
    return "Aku baik banget, $name! Terima kasih sudah bertanya 🥰\n\n"
           "Selalu siap 24/7 buat bantu kamu! Gimana kabarnya hari ini?\n\n"
           "Oh iya, ada yang mau ditanyakan tentang sampah atau tagihan?";
  }

  String _getThankYouResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    if (lang == 'en') {
      final responses = [
        "You're welcome, $name! 😊 Happy to help!\n\nFeel free to ask me anything anytime!",
        "My pleasure, $name! 🌟\n\nDon't hesitate if you need help again!",
        "Glad I could help, $name! ✨\n\nI'm always here whenever you need me!",
      ];
      return responses[DateTime.now().second % responses.length];
    }
    final responses = [
      "Sama-sama, $name! 😊 Senang bisa membantu!\n\nKalau ada yang perlu lagi, langsung tanya aja ya!",
      "Dengan senang hati, $name! 🌟\n\nJangan sungkan-sungkan kalau butuh bantuan lagi ya!",
      "You're welcome, $name! ✨\n\nAku selalu di sini kalau kamu butuh bantuan!",
    ];
    return responses[DateTime.now().second % responses.length];
  }

  String _getHelpResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    if (lang == 'en') {
      return "Of course, $name! Happy to help! 🤗\n\n"
             "Here's what I can do for you:\n\n"
             "💰 **Bills & Payments**\n"
             "   Check your bills and total amount due\n\n"
             "📅 **Pickup Schedule**\n"
             "   Info about when your waste will be collected\n\n"
             "♻️ **Waste Classification**\n"
             "   How to sort your waste properly\n\n"
             "📱 **Open App Menus**\n"
             "   Type \"open articles\", \"open payment history\", etc.\n\n"
             "👤 **Create Service Account**\n"
             "   Say \"create service account\" to register a new one\n\n"
             "🌐 **Bilingual Support**\n"
             "   I speak both Indonesian and English!\n\n"
             "Where would you like to start, $name?";
    }
    return "Tentu, $name! Dengan senang hati! 🤗\n\n"
           "Berikut hal-hal yang bisa aku bantu:\n\n"
           "💰 **Tagihan & Pembayaran**\n"
           "   Cek tagihan, total yang harus dibayar\n\n"
           "📅 **Jadwal Penjemputan**\n"
           "   Info kapan sampah akan dijemput\n\n"
           "♻️ **Klasifikasi Sampah**\n"
           "   Cara memilah sampah dengan benar\n\n"
           "📱 **Buka Menu Layanan**\n"
           "   Ketik \"buka artikel\", \"buka riwayat pembayaran\", dll.\n\n"
           "👤 **Buat Akun Layanan**\n"
           "   Ketik \"buat akun layanan\" untuk daftar akun baru\n\n"
           "🌐 **Dwibahasa**\n"
           "   Aku bisa bahasa Indonesia dan Inggris!\n\n"
           "Mau mulai dari mana, $name?";
  }

  // ========== FAREWELL ==========

  bool _isFarewell(String msg) {
    final farewells = [
      'bye', 'goodbye', 'good bye', 'see you', 'see ya', 'later', 'gotta go',
      'take care', 'have a good day', 'have a nice day', 'good night', 'nite',
      'ttyl', 'talk to you later', 'catch you later', 'peace out', 'im leaving',
      'i have to go', 'i gotta go', 'i need to go', 'signing off',
      'dadah', 'dah', 'sampai jumpa', 'sampai ketemu', 'pamit', 'permisi dulu',
      'aku pergi dulu', 'saya pergi dulu', 'duluan ya', 'cabut dulu',
      'bye bye', 'bai', 'bai bai', 'selamat tinggal', 'wassalam',
      'waalaikumsalam', 'assalamualaikum', 'mau pergi',
    ];
    // Exact short matches
    if (['bye', 'dah', 'dadah', 'bai', 'later'].contains(msg)) return true;
    return farewells.any((f) => msg.contains(f));
  }

  String _getFarewellResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    final r = DateTime.now().second % 3;
    if (lang == 'en') {
      final responses = [
        "Goodbye, $name! 👋 Take care and have a wonderful day! 😊\n\nI'll be here whenever you need me!",
        "See you later, $name! 🌟 It was great talking to you!\n\nDon't hesitate to come back anytime! 💚",
        "Bye bye, $name! 😊 Stay awesome and take care of yourself!\n\nI'm always here 24/7 if you need help! 👋",
      ];
      return responses[r];
    }
    final responses = [
      "Dadah, $name! 👋 Hati-hati dan semoga harimu menyenangkan! 😊\n\nAku selalu di sini kalau kamu butuh bantuan ya!",
      "Sampai jumpa, $name! 🌟 Senang bisa mengobrol denganmu!\n\nJangan sungkan untuk balik lagi kapan saja! 💚",
      "Bye bye, $name! 😊 Jaga kesehatan dan tetap semangat ya!\n\nAku standby 24/7 kalau kamu perlu bantuan! 👋",
    ];
    return responses[r];
  }

  // ========== IDENTITY QUESTIONS ==========

  bool _isIdentityQuestion(String msg) {
    return msg.contains('siapa kamu') || msg.contains('siapa nama') ||
           msg.contains('kamu siapa') || msg.contains('nama kamu') ||
           msg.contains('who are you') || msg.contains('what is your name') ||
           msg.contains("what's your name") || msg.contains('your name') ||
           msg.contains('who is this') || msg.contains('kamu ini apa') ||
           msg.contains('kamu itu apa') || msg.contains('kamu robot') ||
           msg.contains('are you a robot') || msg.contains('are you ai') ||
           msg.contains('are you real') || msg.contains('kamu manusia') ||
           msg.contains('are you human') || msg.contains('apakah kamu') ||
           msg.contains('who made you') || msg.contains('siapa yang buat');
  }

  String _getIdentityResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    if (lang == 'en') {
      return "Great question, $name! 🤖\n\n"
             "I'm **Smart AI**, your virtual assistant for the Sirkular waste management app! ✨\n\n"
             "I'm an AI-powered chatbot designed to help you with:\n"
             "• 💰 Checking bills & payments\n"
             "• 📅 Viewing pickup schedules\n"
             "• 📱 Navigating app menus\n"
             "• 💬 Answering your questions\n\n"
             "I speak both **Indonesian** and **English**! 🌍\n\n"
             "How can I help you today? 😊";
    }
    return "Pertanyaan bagus, $name! 🤖\n\n"
           "Aku **Smart AI**, asisten virtual untuk aplikasi pengelolaan sampah Sirkular! ✨\n\n"
           "Aku adalah chatbot berbasis AI yang siap bantu kamu:\n"
           "• 💰 Cek tagihan & pembayaran\n"
           "• 📅 Lihat jadwal penjemputan\n"
           "• 📱 Navigasi menu aplikasi\n"
           "• 💬 Menjawab pertanyaan kamu\n\n"
           "Aku bisa bahasa **Indonesia** dan **Inggris**! 🌍\n\n"
           "Ada yang bisa aku bantu hari ini? 😊";
  }

  // ========== COMPLIMENTS ==========

  bool _isCompliment(String msg) {
    return msg.contains('pintar') || msg.contains('hebat') || msg.contains('keren') ||
           msg.contains('canggih') || msg.contains('mantap') || msg.contains('bagus') ||
           msg.contains('smart') || msg.contains('clever') || msg.contains('awesome') ||
           msg.contains('great job') || msg.contains('good job') || msg.contains('well done') ||
           msg.contains('amazing') || msg.contains('brilliant') || msg.contains('cool') ||
           msg.contains('nice') || msg.contains('impressive') || msg.contains('love you') ||
           msg.contains('suka kamu') || msg.contains('luar biasa') || msg.contains('top') ||
           msg.contains('good bot') || msg.contains('best') || msg.contains('terbaik');
  }

  String _getComplimentResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    final r = DateTime.now().second % 3;
    if (lang == 'en') {
      final responses = [
        "Aww, thank you so much, $name! 🥰 You're so kind!\n\nI'm always trying my best to help you! 💚",
        "That means a lot to me, $name! 😊✨ You just made my day!\n\nI'll keep doing my best for you!",
        "You're amazing too, $name! 🌟 Thank you for the kind words!\n\nReady to help with anything you need! 💪",
      ];
      return responses[r];
    }
    final responses = [
      "Wah, terima kasih banyak, $name! 🥰 Kamu baik banget!\n\nAku selalu berusaha yang terbaik buat bantu kamu! 💚",
      "Senangnya dipuji, $name! 😊✨ Kamu bikin hariku jadi lebih cerah!\n\nAku akan terus berusaha lebih baik lagi!",
      "Kamu juga keren, $name! 🌟 Makasih ya pujiannya!\n\nSiap bantu apa saja yang kamu butuhkan! 💪",
    ];
    return responses[r];
  }

  // ========== APOLOGY ==========

  bool _isApology(String msg) {
    return msg.contains('maaf') || msg.contains('sorry') || msg.contains('minta maaf') ||
           msg.contains('apologize') || msg.contains('my bad') || msg.contains('salah') ||
           msg.contains('pardon') || msg.contains('ampun');
  }

  String _getApologyResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    if (lang == 'en') {
      return "No worries at all, $name! 😊\n\nYou don't need to apologize! I'm here to help you. 💚\n\nIs there anything I can assist you with?";
    }
    return "Santai aja, $name! 😊\n\nNggak perlu minta maaf kok! Aku di sini untuk bantu kamu. 💚\n\nAda yang bisa aku bantu?";
  }

  // ========== AFFIRMATION ==========

  bool _isAffirmation(String msg) {
    final affirmations = ['ok', 'okay', 'oke', 'oke deh', 'iya', 'ya', 'yes', 'yep', 'yup',
      'yeah', 'sure', 'baik', 'baiklah', 'sip', 'siap', 'boleh', 'tentu', 'betul',
      'benar', 'setuju', 'agree', 'alright', 'right', 'yoi', 'oke siap', 'okey',
      'got it', 'understood', 'i see', 'paham', 'mengerti', 'ngerti'];
    return affirmations.contains(msg) || affirmations.any((a) => msg == a);
  }

  String _getAffirmationResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    final r = DateTime.now().second % 3;
    if (lang == 'en') {
      final responses = [
        "Great, $name! 👍 Is there anything else I can help you with? 😊",
        "Awesome! 😊 Let me know if you need anything else, $name!",
        "Perfect! 👌 I'm here whenever you need me, $name! 💚",
      ];
      return responses[r];
    }
    final responses = [
      "Oke, $name! 👍 Ada hal lain yang bisa aku bantu? 😊",
      "Siap! 😊 Kabari aku kalau ada yang perlu lagi ya, $name!",
      "Mantap! 👌 Aku di sini kalau kamu butuh, $name! 💚",
    ];
    return responses[r];
  }

  // ========== NEGATION ==========

  bool _isNegation(String msg) {
    final negations = ['no', 'nope', 'nah', 'tidak', 'nggak', 'gak', 'enggak', 'engga',
      'ga', 'kagak', 'ndak', 'tak', 'jangan', "don't", 'dont', 'no thanks',
      'no thank you', 'tidak perlu', 'gak usah', 'gak perlu', 'nggak usah',
      'belum', 'tidak ada', 'nothing', 'never mind', 'nevermind', 'udah cukup',
      'sudah cukup', 'cukup'];
    return negations.contains(msg) || negations.any((n) => msg == n);
  }

  String _getNegationResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    if (lang == 'en') {
      return "Alright, $name! No problem at all! 😊\n\nI'll be right here if you change your mind or need anything later! 💚";
    }
    return "Oke, $name! Nggak masalah sama sekali! 😊\n\nAku tetap di sini kalau kamu berubah pikiran atau butuh bantuan nanti ya! 💚";
  }

  // ========== EMOTIONAL EXPRESSIONS ==========

  bool _isEmotional(String msg) {
    return msg.contains('sedih') || msg.contains('sad') || msg.contains('senang') ||
           msg.contains('happy') || msg.contains('kesal') || msg.contains('angry') ||
           msg.contains('marah') || msg.contains('bosan') || msg.contains('bored') ||
           msg.contains('stressed') || msg.contains('stres') || msg.contains('capek') ||
           msg.contains('tired') || msg.contains('lelah') || msg.contains('takut') ||
           msg.contains('scared') || msg.contains('afraid') || msg.contains('excited') ||
           msg.contains('semangat') || msg.contains('frustrated') || msg.contains('lonely') ||
           msg.contains('kesepian') || msg.contains('worried') || msg.contains('khawatir') ||
           msg.contains('confused') || msg.contains('bingung') || msg.contains('anxious');
  }

  String _getEmotionalResponse(String msg, String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    // Positive emotions
    if (msg.contains('senang') || msg.contains('happy') || msg.contains('excited') || msg.contains('semangat')) {
      return lang == 'en'
        ? "That's wonderful to hear, $name! 🎉😊\n\nYour positive energy is contagious! Keep it up! 💚\n\nAnything I can help with to make your day even better?"
        : "Senangnya dengar itu, $name! 🎉😊\n\nEnergi positifmu itu menular lho! Pertahankan ya! 💚\n\nAda yang bisa aku bantu biar harimu makin baik?";
    }
    // Negative emotions
    if (msg.contains('sedih') || msg.contains('sad') || msg.contains('lonely') || msg.contains('kesepian')) {
      return lang == 'en'
        ? "I'm sorry to hear that, $name 😢\n\nRemember, it's okay to feel that way. Things will get better! 🌈\n\nI'm here to chat if you need company. How about I help you with something? 💚"
        : "Aku turut prihatin, $name 😢\n\nIngat ya, wajar kok kalau merasa seperti itu. Semua akan membaik! 🌈\n\nAku di sini kalau kamu butuh teman ngobrol. Mau aku bantu sesuatu? 💚";
    }
    if (msg.contains('marah') || msg.contains('angry') || msg.contains('kesal') || msg.contains('frustrated')) {
      return lang == 'en'
        ? "I understand, $name. It's normal to feel that way sometimes. 😤\n\nTake a deep breath! 🌬️ I hope I can help make things a little better.\n\nWant me to help with anything? 💚"
        : "Aku paham, $name. Wajar kok merasa seperti itu kadang. 😤\n\nTarik napas dalam-dalam ya! 🌬️ Semoga aku bisa sedikit membantu.\n\nMau aku bantu sesuatu? 💚";
    }
    if (msg.contains('capek') || msg.contains('tired') || msg.contains('lelah') || msg.contains('stres') || msg.contains('stressed')) {
      return lang == 'en'
        ? "Take it easy, $name! 😊\n\nYou've been working hard! Don't forget to rest and take care of yourself. 🛁\n\nI'll handle the app stuff for you — just ask! 💪"
        : "Santai dulu, $name! 😊\n\nKamu sudah kerja keras! Jangan lupa istirahat dan jaga kesehatan ya. 🛁\n\nBiar aku yang urus urusan aplikasi — tinggal bilang aja! 💪";
    }
    if (msg.contains('bosan') || msg.contains('bored')) {
      return lang == 'en'
        ? "Feeling bored, $name? 🤔\n\nHow about reading some interesting **articles** in the app? 📰\n\nOr ask me anything — I'm always up for a chat! 😊"
        : "Lagi bosan ya, $name? 🤔\n\nGimana kalau baca **artikel** menarik di aplikasi? 📰\n\nAtau ngobrol aja sama aku — aku selalu siap menemani! 😊";
    }
    // Generic emotional response
    return lang == 'en'
      ? "I hear you, $name. 💚 Your feelings are valid!\n\nI'm always here if you want to talk or need help with anything. Just let me know! 😊"
      : "Aku dengar kamu, $name. 💚 Perasaanmu itu valid kok!\n\nAku selalu di sini kalau mau ngobrol atau butuh bantuan. Bilang aja ya! 😊";
  }

  // ========== JOKE REQUEST ==========

  bool _isJokeRequest(String msg) {
    return msg.contains('joke') || msg.contains('lelucon') || msg.contains('lucu') ||
           msg.contains('funny') || msg.contains('humor') || msg.contains('becanda') ||
           msg.contains('bercanda') || msg.contains('guyon') || msg.contains('jokes') ||
           msg.contains('tell me something') || msg.contains('make me laugh') ||
           msg.contains('ceritain') || msg.contains('hibur');
  }

  String _getJokeResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    final jokes = lang == 'en' ? [
      "Why did the trash can blush? 😄\n\nBecause it saw the garbage truck coming to pick it up! 🚛\n\nHaha! Hope that made you smile, $name! 😊",
      "What did the recycling bin say to the trash? 🤔\n\n\"You're such a waste!\" 😂\n\nGet it? Okay, I'll stop... 😅 Need help with anything, $name?",
      "I told my friend a joke about waste management...\n\nIt was garbage! 🗑️😂\n\nBut hey, at least it's recycled humor! Need anything, $name? 😊",
    ] : [
      "Kenapa tempat sampah malu? 😄\n\nKarena diliatin sama truk sampah! 🚛\n\nHaha! Semoga bikin kamu senyum, $name! 😊",
      "Tong sampah bilang ke sampah: 🤔\n\n\"Kamu emang nggak berguna, tapi aku tetap terima kamu!\" 😂\n\nWkwk, butuh bantuan apa, $name? 😊",
      "Aku punya lelucon tentang daur ulang...\n\nTapi itu lelucon bekas! ♻️😂\n\nSetidaknya itu ramah lingkungan! Ada yang bisa dibantu, $name? 😊",
    ];
    return jokes[DateTime.now().second % jokes.length];
  }

  // ========== TIME/DATE QUERY ==========

  bool _isTimeQuery(String msg) {
    return msg.contains('jam berapa') || msg.contains('what time') || msg.contains('tanggal berapa') ||
           msg.contains('what date') || msg.contains('hari apa') || msg.contains('what day') ||
           msg.contains('sekarang jam') || msg.contains('current time') || msg.contains('hari ini') ||
           msg.contains('today') || msg.contains('waktu sekarang');
  }

  String _getTimeResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final days = lang == 'en'
      ? ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday']
      : ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
    final months = lang == 'en'
      ? ['January','February','March','April','May','June','July','August','September','October','November','December']
      : ['Januari','Februari','Maret','April','Mei','Juni','Juli','Agustus','September','Oktober','November','Desember'];
    final day = days[now.weekday - 1];
    final month = months[now.month - 1];
    if (lang == 'en') {
      return "Sure, $name! ⏰\n\nRight now it's **$hour:$minute** on **$day, $month ${now.day}, ${now.year}**.\n\nAnything else I can help with? 😊";
    }
    return "Siap, $name! ⏰\n\nSekarang jam **$hour:$minute**, hari **$day, ${now.day} $month ${now.year}**.\n\nAda lagi yang mau ditanyakan? 😊";
  }

  // ========== ABOUT APP ==========

  bool _isAboutApp(String msg) {
    return msg.contains('aplikasi ini') || msg.contains('this app') ||
           msg.contains('about this') || msg.contains('tentang aplikasi') ||
           msg.contains('sirkular') || msg.contains('apa ini') ||
           msg.contains('what is this') || msg.contains('fungsi aplikasi') ||
           msg.contains('kegunaan') || msg.contains('purpose');
  }

  String _getAboutAppResponse(String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    if (lang == 'en') {
      return "Great question, $name! 📱\n\n"
             "**Sirkular** is a smart waste management app that helps you:\n\n"
             "🗑️ **Waste Collection** — Schedule and track your waste pickups\n"
             "💰 **Billing** — View and manage your waste management bills\n"
             "📰 **Articles** — Read tips about waste management & environment\n"
             "📊 **Reports** — Submit reports and complaints\n"
             "🤖 **Smart AI** — That's me! Your 24/7 virtual assistant\n\n"
             "Together, let's create a cleaner environment! 🌍💚";
    }
    return "Pertanyaan bagus, $name! 📱\n\n"
           "**Sirkular** adalah aplikasi pengelolaan sampah pintar yang membantumu:\n\n"
           "🗑️ **Penjemputan Sampah** — Jadwalkan dan lacak penjemputan\n"
           "💰 **Tagihan** — Lihat dan kelola tagihan pengelolaan sampah\n"
           "📰 **Artikel** — Baca tips pengelolaan sampah & lingkungan\n"
           "📊 **Pelaporan** — Kirim laporan dan keluhan\n"
           "🤖 **Smart AI** — Itu aku! Asisten virtual 24/7 kamu\n\n"
           "Bersama, mari ciptakan lingkungan yang lebih bersih! 🌍💚";
  }

  String _getConversationalFallback(String lowerMsg, String? userName, String lang) {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    
    // Check for waste classification questions
    if (lowerMsg.contains('sampah') || lowerMsg.contains('buang') || 
        lowerMsg.contains('pilah') || lowerMsg.contains('daur ulang') ||
        lowerMsg.contains('waste') || lowerMsg.contains('garbage') ||
        lowerMsg.contains('trash') || lowerMsg.contains('recycle') ||
        lowerMsg.contains('sort') || lowerMsg.contains('rubbish')) {
      if (lang == 'en') {
        return "Great question about waste, $name! 🌱\n\n"
               "Here are some quick tips:\n"
               "♻️ **Organic waste** — food scraps, leaves → compost\n"
               "📦 **Inorganic waste** — plastic, metal, glass → recycle\n"
               "⚠️ **Hazardous waste** — batteries, chemicals → special disposal\n\n"
               "I can also help you:\n"
               "• Check your waste management **bills**\n"
               "• View your waste **pickup schedule**\n\n"
               "Which one would you like? 😊";
      }
      return "Pertanyaan bagus tentang sampah, $name! 🌱\n\n"
             "Ini beberapa tips singkat:\n"
             "♻️ **Sampah organik** — sisa makanan, daun → kompos\n"
             "📦 **Sampah anorganik** — plastik, logam, kaca → daur ulang\n"
             "⚠️ **Sampah B3** — baterai, bahan kimia → pembuangan khusus\n\n"
             "Aku juga bisa bantu:\n"
             "• Cek **tagihan** pengelolaan sampah\n"
             "• Info **jadwal** penjemputan sampah\n\n"
             "Mau cek yang mana? 😊";
    }

    // Weather / cuaca
    if (lowerMsg.contains('cuaca') || lowerMsg.contains('weather') || lowerMsg.contains('hujan') || 
        lowerMsg.contains('rain') || lowerMsg.contains('panas') || lowerMsg.contains('hot')) {
      return lang == 'en'
        ? "I don't have weather data, $name 🌤️\n\nBut here's a tip: if it's rainy, make sure your waste bags are covered so they don't get wet before pickup! ☔\n\nAnything else I can help with? 😊"
        : "Aku belum punya data cuaca, $name 🌤️\n\nTapi tips: kalau hujan, pastikan kantong sampahmu tertutup biar nggak basah sebelum dijemput! ☔\n\nAda yang lain bisa aku bantu? 😊";
    }

    // Random/gibberish - very short messages
    if (lowerMsg.length <= 2) {
      return lang == 'en'
        ? "Hmm, could you say that again, $name? 🤔 I didn't quite catch that!\n\nYou can ask me about bills, schedules, or just chat! 😊"
        : "Hmm, bisa diulangi, $name? 🤔 Aku kurang jelas dengarnya!\n\nKamu bisa tanya soal tagihan, jadwal, atau ngobrol aja! 😊";
    }

    // Profanity / insults
    if (lowerMsg.contains('bodoh') || lowerMsg.contains('goblok') || lowerMsg.contains('stupid') ||
        lowerMsg.contains('idiot') || lowerMsg.contains('dumb') || lowerMsg.contains('useless') ||
        lowerMsg.contains('tolol') || lowerMsg.contains('bego')) {
      return lang == 'en'
        ? "I'm sorry if I disappointed you, $name 😅\n\nI'm still learning and improving every day! Let me try to help you better.\n\nWhat do you need help with? 💚"
        : "Maaf kalau aku mengecewakan, $name 😅\n\nAku masih terus belajar dan berkembang! Aku akan berusaha lebih baik.\n\nApa yang bisa aku bantu? 💚";
    }

    // Singing / music
    if (lowerMsg.contains('nyanyi') || lowerMsg.contains('sing') || lowerMsg.contains('lagu') || 
        lowerMsg.contains('song') || lowerMsg.contains('music') || lowerMsg.contains('musik')) {
      return lang == 'en'
        ? "Haha, I wish I could sing for you, $name! 🎵\n\nBut my voice is meant for answering questions, not winning talent shows! 😂\n\nHow about I help you with something else? 😊"
        : "Haha, andai aku bisa nyanyi, $name! 🎵\n\nTapi suaraku cuma buat jawab pertanyaan, bukan buat ikut audisi! 😂\n\nGimana kalau aku bantu hal lain? 😊";
    }

    // Default smart fallback - more friendly and helpful
    if (lang == 'en') {
      return "Hmm, that's an interesting one, $name! 🤔\n\n"
             "I might not have the answer for that, but here's what I'm great at:\n\n"
             "💰 **Bills** — \"check my bill\" or \"how much do I owe\"\n"
             "📅 **Schedule** — \"my schedule\" or \"when is pickup\"\n"
             "📱 **Navigate** — \"open articles\", \"open payment history\"\n"
             "🤖 **Chat** — greetings, jokes, time, and more!\n\n"
             "Try one of these! 😊";
    }
    return "Hmm, menarik juga itu, $name! 🤔\n\n"
           "Aku mungkin belum bisa jawab itu, tapi ini hal yang aku jago:\n\n"
           "💰 **Tagihan** — \"berapa tagihan saya\" atau \"cek tagihan\"\n"
           "📅 **Jadwal** — \"jadwal jemput\" atau \"kapan dijemput\"\n"
           "📱 **Navigasi** — \"buka artikel\", \"buka riwayat pembayaran\"\n"
           "🤖 **Ngobrol** — sapaan, lelucon, waktu, dan lainnya!\n\n"
           "Yuk, coba salah satu! 😊";
  }

  // ========== PAY BILL QUERY ==========

  /// Extract payment type and channel from user message.
  /// Returns a map with 'type' and optional 'channel' keys.
  /// Returns null if no specific payment method is detected.
  Map<String, String>? _extractPaymentMethod(String msg) {
    // Virtual Account detection
    if (msg.contains('virtual account') || msg.contains('va ') || msg.contains(' va') ||
        msg.contains('transfer') || msg.contains('bank transfer')) {
      // Detect specific bank
      if (msg.contains('bca')) return {'type': 'va', 'channel': 'bca'};
      if (msg.contains('bni')) return {'type': 'va', 'channel': 'bni'};
      if (msg.contains('bri')) return {'type': 'va', 'channel': 'bri'};
      if (msg.contains('permata')) return {'type': 'va', 'channel': 'permata'};
      if (msg.contains('mandiri')) return {'type': 'va', 'channel': 'bca'}; // fallback
      // VA without specific bank — default to BCA
      return {'type': 'va', 'channel': 'bca'};
    }

    // QRIS detection
    if (msg.contains('qris') || msg.contains('qr code') || msg.contains('scan qr') ||
        msg.contains('kode qr')) {
      return {'type': 'qris', 'channel': 'qris'};
    }

    // E-Wallet detection
    if (msg.contains('gopay') || msg.contains('go pay') || msg.contains('go-pay')) {
      return {'type': 'ewallet', 'channel': 'gopay'};
    }
    if (msg.contains('shopeepay') || msg.contains('shopee pay') || msg.contains('shopee')) {
      return {'type': 'ewallet', 'channel': 'shopeepay'};
    }
    if (msg.contains('e-wallet') || msg.contains('ewallet') || msg.contains('e wallet') ||
        msg.contains('dompet digital')) {
      return {'type': 'ewallet', 'channel': 'gopay'}; // default to gopay
    }

    // Dana, OVO not supported but provide fallback
    if (msg.contains('dana') || msg.contains('ovo')) {
      return {'type': 'ewallet', 'channel': 'gopay'}; // fallback to gopay
    }

    return null; // No specific payment method detected
  }

  /// Get a friendly display name for payment method
  String _getPaymentMethodDisplayName(String type, String? channel) {
    switch (type) {
      case 'va':
        return '${channel?.toUpperCase() ?? 'BCA'} Virtual Account';
      case 'qris':
        return 'QRIS';
      case 'ewallet':
        return channel?.toUpperCase() ?? 'E-Wallet';
      default:
        return type;
    }
  }

  Future<ChatbotResponse> _handlePayBillQuery(String msg, {String? serviceAccountId, String? userName, String lang = 'id'}) async {
    final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
    try {
      final data = await _invoiceService.getUnpaidInvoices();

      List<dynamic> invoices = [];

      if (data.containsKey('unpaid_invoices') && data['unpaid_invoices'] is List) {
        invoices = data['unpaid_invoices'];
      } else if (data.containsKey('invoices') && data['invoices'] is List) {
        invoices = data['invoices'];
      } else if (data.values.any((v) => v is List)) {
        for (var v in data.values) {
          if (v is List) {
            invoices = v;
            break;
          }
        }
      }

      // Filter by service account ID if provided
      if (serviceAccountId != null && serviceAccountId.isNotEmpty) {
        invoices = invoices.where((inv) {
          final serviceAccount = inv['service_account'];
          if (serviceAccount == null) return false;
          final invoiceAccountId = serviceAccount['id']?.toString();
          return invoiceAccountId == serviceAccountId;
        }).toList();
      }

      if (invoices.isEmpty) {
        if (lang == 'en') {
          return ChatbotResponse(
            message: "Great news, $name! \u{1F389}\n\n"
                "You don't have any unpaid bills at the moment.\n\n"
                "No need to pay anything! Thank you for always paying on time! \u{1F49A}",
          );
        }
        return ChatbotResponse(
          message: "Kabar baik, $name! \u{1F389}\n\n"
              "Kamu tidak punya tagihan yang belum dibayar saat ini.\n\n"
              "Nggak perlu bayar apa-apa! Terima kasih sudah selalu bayar tepat waktu! \u{1F49A}",
        );
      }

      // Calculate total and build details
      double totalAmount = 0;
      List<String> details = [];
      List<Map<String, dynamic>> invoiceDataList = [];
      List<int> invoiceIds = [];

      for (var inv in invoices) {
        final amount = double.tryParse(inv['total_amount']?.toString() ?? inv['amount']?.toString() ?? '0') ?? 0;
        totalAmount += amount;

        String period = inv['period']?.toString() ?? '';
        if (period.isEmpty) {
          period = inv['billing_period']?.toString() ??
              inv['invoice_number']?.toString() ??
              (lang == 'en' ? 'Unknown period' : 'Periode tidak diketahui');
        }

        final serviceAccount = inv['service_account'];
        final accountName = serviceAccount is Map ? (serviceAccount['name']?.toString() ?? '') : '';

        final formattedAmount = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(amount);

        if (accountName.isNotEmpty) {
          details.add("   \u2022 $accountName ($period): $formattedAmount");
        } else {
          details.add("   \u2022 $period: $formattedAmount");
        }

        invoiceDataList.add(Map<String, dynamic>.from(inv));
        if (inv['id'] != null) {
          invoiceIds.add(inv['id'] as int);
        }
      }

      final totalFormatted = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(totalAmount);

      // --- Try to detect payment method from user message ---
      final paymentMethod = _extractPaymentMethod(msg);

      if (paymentMethod != null && invoiceIds.isNotEmpty) {
        // User specified a payment method -> auto-process payment!
        final paymentType = paymentMethod['type']!;
        final paymentChannel = paymentMethod['channel'];
        final methodName = _getPaymentMethodDisplayName(paymentType, paymentChannel);

        try {
          final payment = await _paymentService.createPayment(
            invoiceIds: invoiceIds,
            paymentType: paymentType,
            paymentChannel: paymentChannel,
          );

          // Payment created successfully!
          if (lang == 'en') {
            return ChatbotResponse(
              message: "Done, $name! \u2705 I've processed your payment automatically!\n\n"
                  "\u{1F4CB} **Payment Details:**\n\n"
                  "${details.join('\n')}\n\n"
                  "\u{1F4B0} **Total: $totalFormatted**\n"
                  "\u{1F4B3} **Method: $methodName**\n\n"
                  "Your payment is being processed now. Please complete the payment following the instructions on the payment screen! \u{1F60A}",
              autoNavigate: true,
              paymentResult: payment,
            );
          }

          return ChatbotResponse(
            message: "Selesai, $name! \u2705 Aku sudah proses pembayaran kamu secara otomatis!\n\n"
                "\u{1F4CB} **Detail Pembayaran:**\n\n"
                "${details.join('\n')}\n\n"
                "\u{1F4B0} **Total: $totalFormatted**\n"
                "\u{1F4B3} **Metode: $methodName**\n\n"
                "Pembayaran kamu sedang diproses sekarang. Silakan selesaikan pembayaran sesuai instruksi di halaman pembayaran! \u{1F60A}",
            autoNavigate: true,
            paymentResult: payment,
          );
        } catch (e) {
          // Payment creation failed — fallback to manual selection
          final errorMsg = e.toString().replaceAll('Exception: ', '');
          if (lang == 'en') {
            return ChatbotResponse(
              message: "Sorry $name, I tried to process your payment with **$methodName** but encountered an issue: $errorMsg\n\n"
                  "\u{1F4CB} **Your Bill Summary:**\n\n"
                  "${details.join('\n')}\n\n"
                  "\u{1F4B0} **Total: $totalFormatted**\n\n"
                  "Please try choosing a payment method manually. \u{1F60A}",
              actions: [
                const ChatbotNavAction(
                  route: 'payment_method',
                  label: 'Choose Payment Method',
                  icon: 'payment',
                ),
              ],
              invoiceData: invoiceDataList,
            );
          }
          return ChatbotResponse(
            message: "Maaf $name, aku sudah coba proses pembayaran dengan **$methodName** tapi ada kendala: $errorMsg\n\n"
                "\u{1F4CB} **Ringkasan Tagihan:**\n\n"
                "${details.join('\n')}\n\n"
                "\u{1F4B0} **Total: $totalFormatted**\n\n"
                "Silakan coba pilih metode pembayaran secara manual ya. \u{1F60A}",
            actions: [
              const ChatbotNavAction(
                route: 'payment_method',
                label: 'Pilih Metode Pembayaran',
                icon: 'payment',
              ),
            ],
            invoiceData: invoiceDataList,
          );
        }
      }

      // --- No specific payment method detected → open payment method screen ---
      if (lang == 'en') {
        return ChatbotResponse(
          message: "Sure, $name! I'll help you pay your bill! \u{1F4B3}\n\n"
              "\u{1F4CB} **Your Bill Summary:**\n\n"
              "You have **${invoices.length} unpaid bill(s)**:\n\n"
              "${details.join('\n')}\n\n"
              "\u{1F4B0} **Total: $totalFormatted**\n\n"
              "I'm opening the payment page for you now! Please choose your preferred payment method.\n\n"
              "\u{1F4A1} **Tip:** You can also say \"pay with BCA\" or \"pay with QRIS\" and I'll process it automatically! \u{1F60A}",
          actions: [
            const ChatbotNavAction(
              route: 'payment_method',
              label: 'Bayar Sekarang',
              icon: 'payment',
            ),
          ],
          autoNavigate: true,
          invoiceData: invoiceDataList,
        );
      }

      return ChatbotResponse(
        message: "Siap, $name! Aku bantu bayar tagihan kamu ya! \u{1F4B3}\n\n"
            "\u{1F4CB} **Ringkasan Tagihan:**\n\n"
            "Kamu punya **${invoices.length} tagihan** yang belum dibayar:\n\n"
            "${details.join('\n')}\n\n"
            "\u{1F4B0} **Total: $totalFormatted**\n\n"
            "Aku bukakan halaman pembayaran sekarang! Silakan pilih metode pembayaran yang kamu mau.\n\n"
            "\u{1F4A1} **Tips:** Kamu juga bisa bilang \"bayar pakai BCA\" atau \"bayar pakai QRIS\" dan aku akan proses otomatis! \u{1F60A}",
        actions: [
          const ChatbotNavAction(
            route: 'payment_method',
            label: 'Bayar Sekarang',
            icon: 'payment',
          ),
        ],
        autoNavigate: true,
        invoiceData: invoiceDataList,
      );
    } catch (e) {
      if (lang == 'en') {
        return ChatbotResponse(
          message: "Oops, sorry $name! 😅\n\n"
              "I'm having trouble fetching your bill data for payment. "
              "Please try again in a moment!\n\n"
              "If the problem persists, you can pay manually through the **Transaction** menu.",
        );
      }
      return ChatbotResponse(
        message: "Waduh, maaf $name! 😅\n\n"
            "Aku lagi kesulitan ngambil data tagihan kamu untuk pembayaran. "
            "Coba lagi dalam beberapa saat ya!\n\n"
            "Kalau masih error, kamu bisa bayar manual lewat menu **Transaksi**.",
      );
    }
  }

  // ========== BILL QUERY ==========

  Future<String> _handleBillQuery({String? serviceAccountId, String? userName, String lang = 'id'}) async {
      final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
      try {
          final data = await _invoiceService.getUnpaidInvoices();
          
          List<dynamic> invoices = [];
          
          if (data.containsKey('unpaid_invoices') && data['unpaid_invoices'] is List) {
              invoices = data['unpaid_invoices'];
          } else if (data.containsKey('invoices') && data['invoices'] is List) {
              invoices = data['invoices'];
          } else if (data.values.any((v) => v is List)) {
               for (var v in data.values) {
                   if (v is List) {
                       invoices = v;
                       break;
                   }
               }
          }

          // Filter by service account ID if provided
          if (serviceAccountId != null && serviceAccountId.isNotEmpty) {
              invoices = invoices.where((inv) {
                  final serviceAccount = inv['service_account'];
                  if (serviceAccount == null) return false;
                  final invoiceAccountId = serviceAccount['id']?.toString();
                  return invoiceAccountId == serviceAccountId;
              }).toList();
          }

          if (invoices.isEmpty) {
              if (lang == 'en') {
                return "Great news, $name! 🎉\n\n"
                       "You don't have any unpaid bills at the moment.\n\n"
                       "Thank you for always paying on time! 💚";
              }
              return "Kabar baik, $name! 🎉\n\n"
                     "Kamu tidak punya tagihan yang belum dibayar saat ini.\n\n"
                     "Terima kasih sudah selalu bayar tepat waktu! 💚";
          }

          double totalAmount = 0;
          List<String> details = [];

          for (var inv in invoices) {
              final amount = double.tryParse(inv['total_amount']?.toString() ?? inv['amount']?.toString() ?? '0') ?? 0;
              totalAmount += amount;
              
              String period = inv['period']?.toString() ?? '';
              if (period.isEmpty) {
                  period = inv['billing_period']?.toString() ?? 
                           inv['invoice_number']?.toString() ?? 
                           (lang == 'en' ? 'Unknown period' : 'Periode tidak diketahui');
              }
              
              final serviceAccount = inv['service_account'];
              final accountName = serviceAccount is Map ? (serviceAccount['name']?.toString() ?? '') : '';
              
              final formattedAmount = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(amount);
              
              if (accountName.isNotEmpty) {
                  details.add("   • $accountName ($period): $formattedAmount");
              } else {
                  details.add("   • $period: $formattedAmount");
              }
          }

          final totalFormatted = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0).format(totalAmount);

          if (lang == 'en') {
            return "Let me check, $name... 🔍\n\n"
                   "📋 **Your Bill Summary:**\n\n"
                   "You have **${invoices.length} unpaid bill(s)**:\n\n"
                   "${details.join('\n')}\n\n"
                   "💰 **Total: $totalFormatted**\n\n"
                   "You can pay through the **Transaction** menu! "
                   "Need anything else? 😊";
          }
          return "Oke $name, aku cek dulu ya... 🔍\n\n"
                 "📋 **Ringkasan Tagihan Kamu:**\n\n"
                 "Kamu punya **${invoices.length} tagihan** yang belum dibayar:\n\n"
                 "${details.join('\n')}\n\n"
                 "💰 **Total: $totalFormatted**\n\n"
                 "Kamu bisa bayar lewat menu **Transaksi** ya! "
                 "Kalau butuh bantuan lagi, tanya aja! 😊";

      } catch (e) {
          if (lang == 'en') {
            return "Oops, sorry $name! 😅\n\n"
                   "I'm having trouble fetching your bill data. "
                   "Please try again in a moment!\n\n"
                   "If the problem persists, contact our support team.";
          }
          return "Waduh, maaf $name! 😅\n\n"
                 "Aku lagi kesulitan ngambil data tagihan kamu. "
                 "Coba lagi dalam beberapa saat ya!\n\n"
                 "Kalau masih error, hubungi CS kami.";
      }
  }

  // ========== SCHEDULE QUERY ==========

  Future<String> _handleScheduleQuery({String? serviceAccountId, String? userName, String lang = 'id'}) async {
      final name = userName ?? (lang == 'en' ? 'there' : 'Kak');
      try {
          final result = await _pickupService.getUpcomingPickups(
            serviceAccountId: serviceAccountId,
          );
          
          if (!result.$1) {
              if (lang == 'en') {
                return "Sorry $name, I couldn't fetch the schedule data 😅\n\n"
                       "Please try again in a moment!";
              }
              return "Maaf $name, aku gagal ngambil data jadwal 😅\n\n"
                     "Coba lagi dalam beberapa saat ya!";
          }

          final pickups = result.$3;
          if (pickups == null || pickups.isEmpty) {
              if (lang == 'en') {
                return "Hmm, it seems there's no upcoming waste pickup scheduled for your account, $name. 📅\n\n"
                       "I'll let you know when there's an update!";
              }
              return "Hmm, sepertinya belum ada jadwal penjemputan sampah dalam waktu dekat untuk akun kamu, $name. 📅\n\n"
                     "Kalau ada update, aku kabari ya!";
          }

          String response = lang == 'en'
              ? "Here you go, $name! Your waste pickup schedule: 📅\n\n"
              : "Siap, $name! Ini jadwal penjemputan sampah kamu: 📅\n\n";
          
          for (var p in pickups) {
             final date = p['pickup_date'] ?? (lang == 'en' ? 'Unknown date' : 'Tanggal tidak diketahui');
             final day = p['day_name'] ?? '';
             String type = lang == 'en' ? 'General' : 'Umum';
             if (p['waste_type'] is String) {
                type = p['waste_type'];
             } else if (p['waste_type'] is Map) {
                type = p['waste_type']['name'] ?? (lang == 'en' ? 'General' : 'Umum');
             }
             
             final status = p['status'] ?? (lang == 'en' ? 'Scheduled' : 'Terjadwal');
             String statusEmoji = status.toLowerCase().contains('selesai') || 
                                  status.toLowerCase().contains('completed') ? '✅' : '🕐';
             
             response += "📍 **$day, $date**\n";
             response += "   ${lang == 'en' ? 'Type' : 'Jenis'}: $type\n";
             response += "   Status: $statusEmoji $status\n\n";
          }

          if (lang == 'en') {
            response += "💡 **Tip:** Make sure your waste is ready before the collector arrives!\n\n"
                        "Anything else you'd like to know, $name? 😊";
          } else {
            response += "💡 **Tips:** Pastikan sampah sudah siap sebelum petugas datang ya!\n\n"
                        "Ada yang mau ditanyakan lagi, $name? 😊";
          }
          return response;

      } catch (e) {
          if (lang == 'en') {
            return "Oops, sorry $name! 😅\n\n"
                   "I'm having trouble fetching the schedule data. "
                   "Please try again in a moment!";
          }
          return "Waduh, maaf $name! 😅\n\n"
                 "Aku lagi kesulitan ngambil data jadwal. "
                 "Coba lagi dalam beberapa saat ya!";
      }
  }
}

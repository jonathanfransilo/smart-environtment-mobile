import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'notification_screen.dart';
import 'tips_detail_screen.dart';
import 'payment_method_screen.dart';
import 'payment_process_screen.dart';
import 'artikel_detail_screen.dart';
import 'jadwal_pengambilan_screen.dart';
import '../../services/invoice_service.dart';
import '../../services/service_account_service.dart';
import '../../services/notification_helper.dart';
import '../../services/user_storage.dart';
import '../../services/artikel_service.dart';
import '../../services/payment_service.dart';
import '../../models/service_account.dart';
import '../../models/artikel_model.dart';
import 'layanan_sampah_screen.dart';
import 'riwayat_pengambilan_screen.dart';
import 'tambah_akun_layanan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _username = "";
  List<Map<String, dynamic>> _akunList = []; // semua akun layanan
  Map<String, dynamic>? _selectedAkun; // akun yang dipilih

  // untuk deteksi penambahan akun baru (hindari notifikasi saat initial load)
  bool _hasLoadedAkunOnce = false;

  // Flag untuk menampilkan welcome message hanya sekali
  bool _hasShownWelcomeMessage = false;

  // unread notification counter
  int _unreadNotifCount = 0;

  // Profile image path
  String _profileImagePath = '';

  // Debounce untuk notifikasi otomatis - cegah duplikasi
  DateTime? _lastNotificationCheck;

  // Invoice/Tagihan state
  final InvoiceService _invoiceService = InvoiceService();
  final PaymentService _paymentService = PaymentService();
  List<Map<String, dynamic>> _unpaidInvoices = [];
  double _totalUnpaidAmount = 0;
  bool _isLoadingInvoices = false;

  // Currency formatter
  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // TIPS CARD: Page Controller dan state halaman saat ini
  final PageController _tipsController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  // Artikel Terbaru state
  final ArtikelService _artikelService = ArtikelService();
  List<ArtikelModel> _artikelList = [];
  bool _isLoadingArtikel = false;
  final PageController _artikelController = PageController(
    viewportFraction: 0.85,
  );
  int _currentArtikelPage = 0;

  @override
  void initState() {
    super.initState();
    _initAll();

    // Inisialisasi listener untuk PageController Tips
    _tipsController.addListener(() {
      if (_tipsController.page != null) {
        int next = _tipsController.page!.round();
        if (_currentPage != next) {
          setState(() {
            _currentPage = next;
          });
        }
      }
    });

    // Inisialisasi listener untuk PageController Artikel
    _artikelController.addListener(() {
      if (_artikelController.page != null) {
        int next = _artikelController.page!.round();
        if (_currentArtikelPage != next) {
          setState(() {
            _currentArtikelPage = next;
          });
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data ketika screen menjadi visible lagi (misalnya setelah kembali dari screen detail)
    // Ini akan memastikan jadwal selalu update
    // ✅ SOLUSI 2: Hanya refresh data, JANGAN trigger notifikasi lagi
    if (mounted && _hasLoadedAkunOnce) {
      _refreshDataOnly();
      // Refresh foto profil juga saat kembali ke home
      _refreshUser();
    }
  }

  /// Refresh data saja tanpa trigger notifikasi otomatis
  Future<void> _refreshDataOnly() async {
    await _loadAkunLayanan(selectLastIfNotFound: false);
    await _loadUnpaidInvoices();
    await _loadArtikel();
  }

  /// Refresh semua data dari API (untuk pull to refresh)
  Future<void> _refreshAllData() async {
    await _loadAkunLayanan(selectLastIfNotFound: false);
    await _loadUnpaidInvoices();
    await _loadArtikel();
    // ✅ SOLUSI 3: Notifikasi otomatis hanya di-check saat PERTAMA KALI buka app (_initAll)
    // TIDAK saat pull to refresh untuk menghindari duplikasi
  }

  @override
  void dispose() {
    _tipsController.dispose(); // Wajib dispose controller
    _artikelController.dispose(); // Dispose artikel controller
    super.dispose();
  }

  Future<void> _initAll() async {
    await _loadUser();
    await _loadAkunLayanan(selectLastIfNotFound: true);
    await _loadUnreadNotif();
    await _loadUnpaidInvoices();
    await _loadArtikel(); // Load artikel terbaru
    _hasLoadedAkunOnce = true;

    // Check dan trigger notifikasi otomatis
    await _checkAutomaticNotifications();
  }

  /// Check semua notifikasi otomatis (jadwal, tagihan, artikel)
  /// DENGAN DEBOUNCE untuk mencegah duplikasi
  Future<void> _checkAutomaticNotifications() async {
    try {
      // ✅ SOLUSI 1: Debounce - Jangan check jika baru saja di-check (dalam 5 menit)
      final now = DateTime.now();
      if (_lastNotificationCheck != null) {
        final difference = now.difference(_lastNotificationCheck!);
        if (difference.inMinutes < 5) {
          print(
            '[SKIP] [HomeScreen] Skipping notification check - last checked ${difference.inMinutes} minutes ago',
          );
          return;
        }
      }

      print('[NOTIFY] [HomeScreen] Checking automatic notifications...');
      _lastNotificationCheck = now;

      final helper = NotificationHelper();
      await helper.checkAndTriggerNotifications(
        serviceAccountId: _selectedAkun?['id']?.toString(),
      );

      // Refresh unread count setelah check notifikasi
      await _loadUnreadNotif();
      print('[OK] [HomeScreen] Notification check completed');
    } catch (e) {
      print('[ERROR] [HomeScreen] Error checking automatic notifications: $e');
    }
  }

  /// Load unpaid invoices from API
  Future<void> _loadUnpaidInvoices() async {
    if (!mounted) return;
    setState(() => _isLoadingInvoices = true);

    try {
      final data = await _invoiceService.getUnpaidInvoices();
      var invoices = List<Map<String, dynamic>>.from(
        data['unpaid_invoices'] ?? [],
      );

      print('[LIST] [HomeScreen] Loaded ${invoices.length} total unpaid invoices from API');

      // Debug: Print struktur invoice untuk melihat field apa saja yang ada
      for (int i = 0; i < invoices.length; i++) {
        final invoice = invoices[i];
        print('[SEARCH] [HomeScreen] Invoice #${i + 1}:');
        print('   - id: ${invoice['id']}');
        print('   - invoice_number: ${invoice['invoice_number']}');
        print('   - status: ${invoice['status']}');
        print('   - total_amount: ${invoice['total_amount']}');
        print('   - Keys: ${invoice.keys.toList()}');
      }
      
      print('[LIST] [HomeScreen] Menampilkan ${invoices.length} invoice (tanpa filter tambahan)');

      // Filter by selected account if one is selected AND there are multiple accounts
      if (_selectedAkun != null && _akunList.length > 1) {
        final selectedAccountId = _selectedAkun!['id']?.toString();
        print('[SEARCH] [HomeScreen] Filtering by selected account ID: $selectedAccountId');
        
        final filteredInvoices = invoices.where((invoice) {
          final serviceAccount = invoice['service_account'];
          
          // Jika invoice tidak punya service_account, tetap tampilkan
          if (serviceAccount == null) {
            print('   [WARN] Invoice #${invoice['id']} tidak punya service_account, tetap tampilkan');
            return true;
          }
          
          final invoiceAccountId = serviceAccount['id']?.toString();
          final matches = invoiceAccountId == selectedAccountId;
          print('   ${matches ? "[OK]" : "[NO]"} Invoice #${invoice['id']} account: $invoiceAccountId ${matches ? "MATCH" : "NO MATCH"}');
          return matches;
        }).toList();
        
        invoices = filteredInvoices;
        print('[LIST] [HomeScreen] Setelah filter akun: ${invoices.length} invoice');
      }

      // Calculate total amount for filtered invoices
      final totalAmount = invoices.fold<double>(
        0.0,
        (sum, invoice) => sum + ((invoice['total_amount'] ?? 0).toDouble()),
      );

      if (!mounted) return;
      setState(() {
        _unpaidInvoices = invoices;
        _totalUnpaidAmount = totalAmount;
        _isLoadingInvoices = false;
      });
    } catch (e, stackTrace) {
      print('[ERROR] [HomeScreen] Error loading unpaid invoices: $e');
      print('   Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _unpaidInvoices = [];
        _totalUnpaidAmount = 0;
        _isLoadingInvoices = false;
      });
    }
  }

  /// Handle payment button click - check for pending payment first
  Future<void> _handlePaymentClick() async {
    try {
      print(
        '[BTN] [HomeScreen] Payment button clicked, checking for pending payment...',
      );
      // Check if there's a pending payment
      final pendingPayment = await _paymentService.checkPendingPayment();

      if (!mounted) return;

      if (pendingPayment != null) {
        print(
          '[WARN] [HomeScreen] Pending payment found! Order ID: ${pendingPayment.orderId}',
        );
        // Show dialog asking if user wants to continue pending payment
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Pembayaran Belum Selesai',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Text(
              'Anda memiliki pembayaran yang belum selesai. Apakah ingin melanjutkan pembayaran tersebut?',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Batal',
                  style: GoogleFonts.poppins(color: Colors.grey.shade600),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 21, 145, 137),
                ),
                child: Text(
                  'Lanjutkan',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        if (shouldContinue == true) {
          print('[OK] [HomeScreen] User chose to continue pending payment');
          // Navigate to payment process screen with pending payment
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PaymentProcessScreen(payment: pendingPayment),
            ),
          );

          // Refresh if payment was successful
          if (result == true) {
            await _loadUnpaidInvoices();
          }
        } else {
          print('[NO] [HomeScreen] User cancelled pending payment dialog');
        }
      } else {
        print(
          '[NAV] [HomeScreen] No pending payment, proceeding to payment method screen',
        );
        // No pending payment, proceed to payment method screen
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PaymentMethodScreen(invoices: _unpaidInvoices),
          ),
        );

        // Refresh if payment was successful
        if (result == true) {
          await _loadUnpaidInvoices();
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memeriksa status pembayaran: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Load artikel terbaru dari API
  Future<void> _loadArtikel() async {
    if (!mounted) return;
    setState(() => _isLoadingArtikel = true);

    try {
      // Fetch artikel terbaru (limit 5 untuk homepage)
      final articles = await _artikelService.getFeaturedArticles(limit: 5);

      if (!mounted) return;
      setState(() {
        _artikelList = articles;
        _isLoadingArtikel = false;
      });
    } catch (e) {
      print('Error loading artikel: $e');
      if (!mounted) return;
      setState(() {
        _artikelList = [];
        _isLoadingArtikel = false;
      });
    }
  }

  // Initial loader (name + shimmer)
  Future<void> _loadUser() async {
    // Gunakan UserStorage untuk mendapatkan nama user yang tersimpan saat login
    final savedName = await UserStorage.getUserName();

    // Load profile image path dari SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final profilePath = prefs.getString('profile_image') ?? '';

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _username = savedName ?? "User";
      _profileImagePath = profilePath;
      _isLoading = false;
    });
  }

  // Refresh nama user
  Future<void> _refreshUser() async {
    // Gunakan UserStorage untuk mendapatkan nama user terbaru
    final savedName = await UserStorage.getUserName();

    // Refresh profile image
    final prefs = await SharedPreferences.getInstance();
    final profilePath = prefs.getString('profile_image') ?? '';

    if (!mounted) return;
    setState(() {
      _username = savedName ?? "User";
      _profileImagePath = profilePath;
    });
  }

  /// Load jumlah notifikasi (untuk badge)
  Future<void> _loadUnreadNotif() async {
    try {
      final list = await NotificationService.getNotifications();
      if (!mounted) return;
      setState(() {
        _unreadNotifCount = list.where((n) => n['isRead'] == false).length;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unreadNotifCount = 0;
      });
    }
  }

  /// Load akun layanan dari API dan SharedPreferences.
  Future<bool> _loadAkunLayanan({bool selectLastIfNotFound = true}) async {
    final prevCount = _akunList.length;

    try {
      // Try to load from API first
      final serviceAccountService = ServiceAccountService();
      final accounts = await serviceAccountService.fetchAccounts();

      // Convert to Map format for backward compatibility
      final akunList = accounts
          .map(
            (account) => {
              'id': account.id,
              'id_akun': account.id, // Untuk compatibility
              'nama': account.name,
              'alamat': account.address,
              'alamat lengkap': account.address,
              'phone': account.contactPhone ?? '',
              'no_telepon':
                  account.contactPhone ?? '', // ✅ Added for detail screen
              'status': account.status,
              'kecamatan': account.kecamatanName,
              'kelurahan': account.kelurahanName,
              'rw': account.rwName,
              'hari_pengangkutan': account.hariPengangkutan,
            },
          )
          .toList();

      if (!mounted) return false;
      setState(() {
        _akunList = akunList;
        if (akunList.isEmpty) {
          _selectedAkun = null;
        } else {
          if (_selectedAkun != null) {
            // Try to find by id or id_akun
            final selectedId =
                _selectedAkun!['id']?.toString() ??
                _selectedAkun!['id_akun']?.toString();
            final idx = akunList.indexWhere((a) {
              final accountId = a['id']?.toString() ?? a['id_akun']?.toString();
              return accountId == selectedId;
            });
            if (idx != -1) {
              // Update dengan data terbaru dari API (termasuk status yang baru)
              final updatedAccount = akunList[idx];
              final isInactive =
                  updatedAccount['status']?.toString().toLowerCase() ==
                  'inactive';

              print(
                '[SYNC] [HomeScreen] Found account: ${updatedAccount['nama']}, status: ${updatedAccount['status']}',
              );

              if (isInactive) {
                // Jika akun yang dipilih menjadi inactive, pindah ke akun aktif lain
                print(
                  '[WARN] [HomeScreen] Selected account became inactive, switching to active account...',
                );

                // Cari akun aktif pertama
                final activeAccounts = akunList
                    .where(
                      (a) => a['status']?.toString().toLowerCase() == 'active',
                    )
                    .toList();

                if (activeAccounts.isNotEmpty) {
                  _selectedAkun = activeAccounts.first;
                  print(
                    '[OK] [HomeScreen] Switched to active account: ${_selectedAkun!['nama']}, status: ${_selectedAkun!['status']}',
                  );

                  // Trigger refresh data untuk akun yang baru dipilih
                  Future.microtask(() async {
                    await _loadUnpaidInvoices();
                  });
                } else {
                  // Tidak ada akun aktif, tetap di akun inactive tapi user tidak bisa akses
                  _selectedAkun = updatedAccount;
                  print(
                    '[WARN] [HomeScreen] No active accounts found, keeping inactive account: ${_selectedAkun!['nama']}',
                  );
                }
              } else {
                // Akun masih aktif, update dengan data terbaru
                _selectedAkun = updatedAccount;
                print(
                  '[OK] [HomeScreen] Updated selected account: ${_selectedAkun!['nama']}, status: ${_selectedAkun!['status']}',
                );
              }
            } else {
              _selectedAkun = selectLastIfNotFound
                  ? akunList.last
                  : akunList.first;
            }
          } else {
            _selectedAkun = akunList.isNotEmpty ? akunList.last : null;
          }
        }
      });

      final added = (akunList.length > prevCount);
      if (_hasLoadedAkunOnce && added) {
        await NotificationService.addNotification(
          "Akun layanan berhasil dibuat.",
        );
        await _loadUnreadNotif();
      }
      return added;
    } catch (e) {
      // Fallback to SharedPreferences if API fails
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('akun_layanan') ?? [];

      final akunList = <Map<String, dynamic>>[];
      for (final s in data) {
        try {
          final m = Map<String, dynamic>.from(jsonDecode(s));
          akunList.add(m);
        } catch (_) {
          // ignore malformed entry
        }
      }

      if (!mounted) return false;
      setState(() {
        _akunList = akunList;
        if (akunList.isEmpty) {
          _selectedAkun = null;
        } else {
          if (_selectedAkun != null) {
            final idx = akunList.indexWhere(
              (a) => a['id']?.toString() == _selectedAkun!['id']?.toString(),
            );
            if (idx != -1) {
              final updatedAccount = akunList[idx];
              final isInactive =
                  updatedAccount['status']?.toString().toLowerCase() ==
                  'inactive';

              if (isInactive) {
                // Jika akun yang dipilih menjadi inactive, pindah ke akun aktif lain
                final activeAccount = akunList.firstWhere(
                  (a) => a['status']?.toString().toLowerCase() == 'active',
                  orElse: () => updatedAccount,
                );
                _selectedAkun = activeAccount;
              } else {
                _selectedAkun = updatedAccount;
              }
            } else {
              _selectedAkun = selectLastIfNotFound
                  ? akunList.last
                  : akunList.first;
            }
          } else {
            _selectedAkun = akunList.isNotEmpty ? akunList.last : null;
          }
        }
      });

      final added = (akunList.length > prevCount);
      if (_hasLoadedAkunOnce && added) {
        await NotificationService.addNotification(
          "Akun layanan berhasil dibuat.",
        );
        await _loadUnreadNotif();
      }
      return added;
    }
  }

  /// Tampilkan bottom sheet untuk memilih akun (fitur multiple account)
  void _showAkunSelector() async {
    if (_akunList.isEmpty) {
      // Jika belum ada akun, buka halaman tambah akun
      await _openLayananSampahAndRefresh();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    width: 60,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 21, 145, 137),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          "Pilih Akun Layanan",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _openLayananSampahAndRefresh();
                          },
                          icon: const Icon(Icons.add),
                          label: Text("Tambah", style: GoogleFonts.poppins()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: _akunList.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final akun = _akunList[index];
                        final isSelected =
                            _selectedAkun != null &&
                            akun['id']?.toString() ==
                                _selectedAkun!['id']?.toString();
                        final isInactive =
                            akun['status']?.toString().toLowerCase() ==
                            'inactive';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isInactive
                                ? Colors.grey.shade300
                                : const Color.fromARGB(
                                    255,
                                    21,
                                    145,
                                    137,
                                  ).withAlpha(31),
                            child: Icon(
                              Icons.home,
                              color: isInactive
                                  ? Colors.grey.shade600
                                  : const Color.fromARGB(255, 21, 145, 137),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  akun["nama"] ?? "Akun Layanan",
                                  style: GoogleFonts.poppins(
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isInactive
                                        ? Colors.grey.shade600
                                        : Colors.black,
                                  ),
                                ),
                              ),
                              if (isInactive)
                                InkWell(
                                  onTap: () async {
                                    // Simpan BuildContext dan ScaffoldMessenger
                                    final scaffoldMessenger =
                                        ScaffoldMessenger.of(context);
                                    final navigator = Navigator.of(context);
                                    final accountId =
                                        akun['id']?.toString() ?? '';
                                    final accountName =
                                        akun['nama'] ?? 'Akun Layanan';

                                    // Tampilkan dialog konfirmasi
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: Text(
                                          'Aktifkan Akun?',
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        content: Text(
                                          'Apakah Anda yakin ingin mengaktifkan kembali akun "$accountName"?',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              dialogContext,
                                            ).pop(false),
                                            child: Text(
                                              'Batal',
                                              style: GoogleFonts.poppins(),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.of(
                                              dialogContext,
                                            ).pop(true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF4CAF50,
                                              ),
                                            ),
                                            child: Text(
                                              'Aktifkan',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed != true) return;

                                    // Tutup bottom sheet
                                    navigator.pop();

                                    // Tampilkan loading di context yang valid
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (loadingContext) => WillPopScope(
                                        onWillPop: () async => false,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const CircularProgressIndicator(),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'Mengaktifkan akun...',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );

                                    try {
                                      // Validasi ID akun
                                      if (accountId.isEmpty) {
                                        throw Exception('ID akun tidak valid');
                                      }

                                      print(
                                        '[SYNC] [HomeScreen] Activating account: $accountId ($accountName)',
                                      );

                                      // Update status ke active via API
                                      final serviceAccountService =
                                          ServiceAccountService();

                                      // Step 1: Update status via API
                                      await serviceAccountService
                                          .updateAccountStatus(
                                            accountId,
                                            'active',
                                          );

                                      print(
                                        '[OK] [HomeScreen] Account activated via API, waiting for sync...',
                                      );

                                      // Step 2: Tunggu sebentar agar API sync
                                      await Future.delayed(
                                        const Duration(milliseconds: 500),
                                      );

                                      // Step 3: Refresh data dari API
                                      await _loadAkunLayanan(
                                        selectLastIfNotFound: false,
                                      );

                                      print(
                                        '[LIST] [HomeScreen] Accounts after refresh: ${_akunList.map((a) => "${a['nama']}: ${a['status']}").join(", ")}',
                                      );

                                      // Step 4: Temukan dan set akun yang baru diaktifkan
                                      final updatedAkunIndex = _akunList
                                          .indexWhere(
                                            (a) =>
                                                a['id']?.toString() ==
                                                accountId,
                                          );

                                      if (updatedAkunIndex == -1) {
                                        throw Exception(
                                          'Akun tidak ditemukan setelah aktivasi',
                                        );
                                      }

                                      final updatedAkun =
                                          _akunList[updatedAkunIndex];

                                      print(
                                        '[SYNC] [HomeScreen] Setting selected account: ${updatedAkun["nama"]}, status: ${updatedAkun["status"]}',
                                      );

                                      // Step 5: Update selected account dengan setState
                                      if (mounted) {
                                        setState(() {
                                          _selectedAkun = updatedAkun;
                                          print(
                                            '[OK] [HomeScreen] setState called - Selected: ${_selectedAkun!['nama']}, Status: ${_selectedAkun!['status']}',
                                          );
                                        });
                                      }

                                      // Step 6: Refresh invoice dengan akun yang baru
                                      await _loadUnpaidInvoices();

                                      // Step 6.5: Force rebuild dengan setState lagi
                                      if (mounted) {
                                        setState(() {
                                          // Force rebuild UI
                                          print(
                                            '[OK] [HomeScreen] Force UI rebuild',
                                          );
                                        });
                                      }

                                      print(
                                        '[OK] [HomeScreen] All data refreshed successfully',
                                      );

                                      // Step 7: Tutup loading
                                      navigator.pop();

                                      // Step 8: Tampilkan success message
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Akun "$accountName" berhasil diaktifkan',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: const Color(
                                            0xFF4CAF50,
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    } catch (e) {
                                      // Tutup loading jika error
                                      navigator.pop();

                                      // Parse error message untuk user-friendly message
                                      String errorMessage = e.toString();
                                      if (errorMessage.contains('Exception:')) {
                                        errorMessage = errorMessage
                                            .replaceAll('Exception:', '')
                                            .trim();
                                      }

                                      // Tampilkan error
                                      scaffoldMessenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            errorMessage,
                                            style: GoogleFonts.poppins(),
                                          ),
                                          backgroundColor: Colors.red,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4CAF50),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Aktifkan',
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (akun['rw'] != null &&
                                  akun['rw'].toString().isNotEmpty)
                                Text(
                                  '${akun['kelurahan']} • ${akun['rw']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isInactive
                                        ? Colors.grey.shade500
                                        : const Color.fromARGB(
                                            255,
                                            21,
                                            145,
                                            137,
                                          ),
                                  ),
                                ),
                              Text(
                                akun["alamat lengkap"] ?? "-",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isInactive
                                      ? Colors.grey.shade500
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          trailing: isSelected
                              ? Icon(
                                  Icons.check_circle,
                                  color: isInactive
                                      ? Colors.grey.shade500
                                      : const Color.fromARGB(255, 21, 145, 137),
                                )
                              : null,
                          enabled:
                              !isInactive, // Disable tap untuk akun inactive
                          onTap: isInactive
                              ? null
                              : () async {
                                  setState(() {
                                    _selectedAkun = akun;
                                  });
                                  Navigator.pop(context);

                                  // Reload invoices for selected account
                                  await _loadUnpaidInvoices();
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // helper to open tambah akun layanan and refresh states after return
  Future<void> _openLayananSampahAndRefresh() async {
    // Navigate langsung ke TambahAkunLayananScreen
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TambahAkunLayananScreen()),
    );
    final added = await _loadAkunLayanan(selectLastIfNotFound: true);
    if (added) {
      await _loadUnreadNotif();
    }
  }

  // Shimmer loading overlay untuk navigasi ke detail
  void _showShimmerLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.white,
      builder: (BuildContext context) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Card 1
                    Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 2
                    Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 3
                    Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 4
                    Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 5
                    Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Tampilkan welcome message jika ada dari login
    if (!_hasShownWelcomeMessage && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Map && args['welcomeMessage'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      args['welcomeMessage'],
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() {
            _hasShownWelcomeMessage = true;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: _isLoading ? _buildShimmer() : _buildHomeContent(),
    );
  }

  Widget _buildHomeContent() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFE0F7F4), // Mint light
            const Color(0xFFF0F9F8), // Very light mint
            Colors.grey.shade50,
          ],
          stops: const [0.0, 0.3, 0.6],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Custom Header (Halo Warga + Icons) - Bagian dari gradient
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Halo Warga Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Halo ${_isLoading ? 'User' : _username},",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      Text(
                        "Selamat Datang",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  // Icons (Notification & Profile)
                  Row(
                    children: [
                      // 🔔 Notification Icon with Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const NotificationScreen(),
                                ),
                              );
                              await _loadUnreadNotif();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/notification.png',
                                width: 24,
                                height: 24,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.notifications,
                                    color: Color.fromRGBO(21, 145, 137, 1),
                                    size: 24,
                                  );
                                },
                              ),
                            ),
                          ),
                          if (_unreadNotifCount > 0)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  _unreadNotifCount > 9
                                      ? '9+'
                                      : '$_unreadNotifCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      // 👤 Profile Photo
                      GestureDetector(
                        onTap: () async {
                          await Navigator.pushNamed(context, '/profile');
                          await _refreshUser();
                          await _refreshAllData();
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Border hijau dihilangkan
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _profileImagePath.isNotEmpty
                                ? (_profileImagePath.startsWith('http')
                                      ? Image.network(
                                          _profileImagePath,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.person,
                                                  color: Colors.grey[400],
                                                  size: 24,
                                                );
                                              },
                                        )
                                      : Image.file(
                                          File(_profileImagePath),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Icon(
                                                  Icons.person,
                                                  color: Colors.grey[400],
                                                  size: 24,
                                                );
                                              },
                                        ))
                                : Icon(
                                    Icons.person,
                                    color: Colors.grey[400],
                                    size: 24,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Scrollable Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // ✅ Pull to refresh - reload semua data TANPA trigger notifikasi otomatis
                  await _refreshUser(); // Refresh profile image
                  await _refreshAllData();
                  await _loadUnreadNotif();
                  // Notifikasi otomatis sudah di-check saat pertama kali buka app
                  // Tidak perlu di-check lagi saat pull to refresh (mencegah duplikasi)
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  physics:
                      const AlwaysScrollableScrollPhysics(), // Pastikan bisa di-scroll untuk pull to refresh
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== Card 1: Akun Layanan Sampah =====
                      _buildServiceAccountCard(),

                      const SizedBox(height: 16),

                      // ===== Card 2: Tagihan & Pembayaran =====
                      _buildTagihanCard(),

                      const SizedBox(height: 40),

                      // ===== Daftar layanan =====
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Daftar Layanan",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 38,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.85,
                        children: [
                          // 1. Jadwal (icon dari assets/images/calender.png)
                          _menuItem(
                            "assets/images/calender.png",
                            "Jadwal\n Pengambilan",
                            onTap: () {
                              // Gunakan service account yang dipilih
                              if (_akunList.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Anda belum memiliki akun layanan. Silakan buat akun terlebih dahulu.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              final currentAccount = _selectedAkun ?? _akunList.first;
                              final serviceAccountId = int.tryParse(
                                currentAccount['id_akun']?.toString() ?? 
                                currentAccount['id']?.toString() ?? 
                                '1'
                              ) ?? 1;

                              // Navigate ke JadwalPengambilanScreen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => JadwalPengambilanScreen(
                                    serviceAccountId: serviceAccountId,
                                  ),
                                ),
                              );
                            },
                          ),
                          // 2. Request Pengambilan
                          _menuItem(
                            "assets/images/express.jpeg",
                            "Request\nPengambilan",
                            onTap: () {
                              // Gunakan service account yang dipilih
                              if (_akunList.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Anda belum memiliki akun layanan. Silakan buat akun terlebih dahulu.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              // Pass service account data ke express request
                              final currentAccount = _selectedAkun ?? _akunList.first;
                              Navigator.pushNamed(
                                context, 
                                '/express-request',
                                arguments: {
                                  'serviceAccountId': currentAccount['id_akun']?.toString() ?? currentAccount['id']?.toString(),
                                  'serviceAccountName': currentAccount['nama']?.toString(),
                                },
                              );
                            },
                          ),
                          // 3. Riwayat Pengambilan
                          _menuItem(
                            "assets/images/keranjang.png",
                            "Riwayat\nPengambilan",
                            onTap: () async {
                              try {
                                print(
                                  '[BTN] [HomeScreen] Riwayat Pengambilan clicked',
                                );

                                // Navigasi ke riwayat pengambilan sampah
                                if (_akunList.isEmpty) {
                                  print('[WARN] [HomeScreen] No account available');
                                  // Jika belum ada akun, tampilkan snackbar
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Anda belum memiliki akun layanan. Silakan buat akun terlebih dahulu.',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: Colors.orange,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                  return;
                                }

                                // Jika sudah ada akun, buka halaman riwayat
                                final currentAccount =
                                    _selectedAkun ?? _akunList.first;
                                final serviceAccountId =
                                    currentAccount['id_akun']?.toString() ??
                                    currentAccount['id']?.toString() ??
                                    '0';
                                final accountName =
                                    currentAccount['nama']?.toString() ??
                                    'Akun';
                                final accountAddress =
                                    currentAccount['alamat']?.toString() ??
                                    currentAccount['address']?.toString() ??
                                    currentAccount['alamat_lengkap']?.toString();

                                print(
                                  '[LIST] [HomeScreen] Opening history for account: $accountName (ID: $serviceAccountId)',
                                );
                                print(
                                  '[LOC] [HomeScreen] Account address: $accountAddress',
                                );

                                // Validasi ID
                                if (serviceAccountId == '0' ||
                                    serviceAccountId.isEmpty) {
                                  print(
                                    '[ERROR] [HomeScreen] Invalid service account ID',
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'ID akun tidak valid. Silakan refresh halaman.',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                  return;
                                }

                                if (!mounted) return;

                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        RiwayatPengambilanScreen(
                                          serviceAccountId: serviceAccountId,
                                          accountName: accountName,
                                          accountAddress: accountAddress,
                                        ),
                                  ),
                                );

                                print(
                                  '[OK] [HomeScreen] Returned from RiwayatPengambilan',
                                );
                              } catch (e, stackTrace) {
                                print(
                                  '[CRASH] [HomeScreen] Error opening RiwayatPengambilan: $e',
                                );
                                print('Stack trace: $stackTrace');

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Gagal membuka riwayat: ${e.toString()}',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                          ),
                          // 4. Riwayat Pembayaran
                          _menuItem(
                            "assets/images/rekening.png",
                            "Riwayat\nPembayaran",
                            onTap: () {
                              // Gunakan service account yang dipilih
                              if (_akunList.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Anda belum memiliki akun layanan. Silakan buat akun terlebih dahulu.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              // Pass service account data ke riwayat pembayaran
                              final currentAccount = _selectedAkun ?? _akunList.first;
                              Navigator.pushNamed(
                                context,
                                '/riwayat-pembayaran',
                                arguments: {
                                  'serviceAccountId': currentAccount['id_akun']?.toString() ?? currentAccount['id']?.toString(),
                                  'serviceAccountName': currentAccount['nama']?.toString(),
                                },
                              );
                            },
                          ),
                          // 5. Artikel
                          _menuItem(
                            "assets/images/artikel.png",
                            "Artikel",
                            onTap: () {
                              Navigator.pushNamed(context, '/artikel');
                            },
                          ),
                          // 6. Pelaporan
                          _menuItem(
                            "assets/images/pelanggaran.png",
                            "Pelaporan",
                            onTap: () {
                              // Pass service account yang dipilih ke pelaporan
                              final currentAccount = _selectedAkun ?? (_akunList.isNotEmpty ? _akunList.first : null);
                              Navigator.pushNamed(
                                context,
                                '/pelaporan',
                                arguments: currentAccount != null ? {
                                  'serviceAccountId': currentAccount['id_akun']?.toString() ?? currentAccount['id']?.toString(),
                                  'serviceAccountName': currentAccount['nama']?.toString(),
                                } : null,
                              );
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // ===================================================
                      // ===== Artikel Terbaru (TAPPABLE & BERWARNA) =====
                      // ===================================================
                      Text(
                        "Artikel Terbaru",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- PageView Artikel ---
                      _isLoadingArtikel
                          ? _buildArtikelShimmer()
                          : _artikelList.isEmpty
                          ? _buildEmptyArtikel()
                          : SizedBox(
                              height: 180,
                              child: PageView.builder(
                                controller: _artikelController,
                                itemCount: _artikelList.length,
                                itemBuilder: (context, index) {
                                  final artikel = _artikelList[index];
                                  return _buildArtikelCard(artikel);
                                },
                              ),
                            ),

                      // --- Indikator Halaman Artikel ---
                      if (!_isLoadingArtikel && _artikelList.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _artikelList.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentArtikelPage == index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentArtikelPage == index
                                    ? Colors.teal
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 40),

                      // ===================================================
                      // ===== TIPS RAMAH LINGKUNGAN (TAPPABLE & BERWARNA) =====
                      // ===================================================
                      Text(
                        "Tips Ramah Lingkungan",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- PageView Tips ---
                      SizedBox(
                        height: 220,
                        child: PageView(
                          controller: _tipsController,
                          children: [
                            _tipsCard(
                              icon: Icons.recycling,
                              title: "Pisahkan Sampah",
                              subtitle:
                                  "Pisahkan sampah organik & anorganik agar mudah didaur ulang.",
                              index: 0,
                              backgroundColor: const Color.fromARGB(
                                255,
                                21,
                                145,
                                137,
                              ), // Hijau utama
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TipsDetailScreen(
                                      tipTitle: "Pisahkan Sampah",
                                      tipContent:
                                          "Mulai dari sekarang, sediakan dua tempat sampah di rumah Anda. Satu untuk sampah organik (sisa makanan, daun, dll.) dan satu lagi untuk sampah anorganik (plastik, kertas, kaleng, botol). Pemilahan ini mempermudah proses daur ulang dan pengomposan. Pastikan sampah anorganik sudah bersih sebelum dibuang!",
                                    ),
                                  ),
                                );
                              },
                            ),
                            _tipsCard(
                              icon: Icons.lightbulb_outline,
                              title: "Hemat Energi",
                              subtitle:
                                  "Matikan lampu & cabut charger saat tidak digunakan.",
                              index: 1,
                              backgroundColor:
                                  Colors.blue.shade600, // Biru untuk energi
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TipsDetailScreen(
                                      tipTitle: "Hemat Energi",
                                      tipContent:
                                          "Langkah kecil seperti mematikan lampu saat keluar ruangan, mencabut kabel charger yang tidak digunakan, dan meminimalkan penggunaan AC sangat membantu mengurangi emisi karbon. Pertimbangkan untuk beralih ke lampu LED yang lebih hemat energi.",
                                    ),
                                  ),
                                );
                              },
                            ),
                            _tipsCard(
                              icon: Icons.water_drop_outlined,
                              title: "Hemat Air",
                              subtitle:
                                  "Gunakan air seperlunya, perbaiki keran bocor segera.",
                              index: 2,
                              backgroundColor:
                                  Colors.orange.shade700, // Oranye untuk air
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TipsDetailScreen(
                                      tipTitle: "Hemat Air",
                                      tipContent:
                                          "Air adalah sumber daya yang terbatas. Pastikan Anda menutup keran saat menyikat gigi, gunakan shower untuk mandi (lebih hemat dari bathtub), dan segera perbaiki keran atau pipa yang bocor. Selain ramah lingkungan, ini juga menghemat tagihan bulanan Anda!",
                                    ),
                                  ),
                                );
                              },
                            ),
                            _tipsCard(
                              icon: Icons.shopping_bag_outlined,
                              title: "Kurangi Plastik",
                              subtitle:
                                  "Bawa tas belanja sendiri untuk mengurangi sampah plastik.",
                              index: 3,
                              backgroundColor: Colors
                                  .purple
                                  .shade600, // Ungu/Pink untuk plastik
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TipsDetailScreen(
                                      tipTitle: "Kurangi Plastik",
                                      tipContent:
                                          "Sampah plastik membutuhkan waktu ratusan tahun untuk terurai. Selalu bawa tas belanja kain (reusable bag), hindari sedotan plastik, dan bawa botol minum isi ulang (tumbler) saat bepergian. Aksi 3R (Reduce, Reuse, Recycle) sangat penting!",
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // --- Indikator Halaman dengan animasi smooth ---
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          4,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: _currentPage == index ? 10 : 8,
                            width: _currentPage == index ? 28 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? const Color.fromARGB(255, 21, 145, 137)
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: _currentPage == index
                                  ? [
                                      BoxShadow(
                                        color: const Color.fromARGB(
                                          255,
                                          21,
                                          145,
                                          137,
                                        ).withAlpha(102),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Shimmer loading
  Widget _buildShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _shimmerBox(height: 20, width: 150),
          const SizedBox(height: 10),
          _shimmerBox(height: 16, width: 100),
          const SizedBox(height: 20),
          _shimmerBox(height: 80, width: double.infinity, radius: 16),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(
              4,
              (index) => Column(
                children: [
                  _shimmerBox(height: 50, width: 50, radius: 16),
                  const SizedBox(height: 6),
                  _shimmerBox(height: 12, width: 40),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          _shimmerBox(height: 180, width: double.infinity, radius: 16),
          const SizedBox(height: 30),
          _shimmerBox(height: 160, width: double.infinity, radius: 16),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    required double height,
    required double width,
    double radius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  // helper menu item dengan animasi
  Widget _menuItem(String asset, String title, {VoidCallback? onTap}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  // Drop shadow: blur 7, offset Y=4, X=0
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 7,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onTap,
                  splashColor: const Color.fromARGB(
                    255,
                    21,
                    145,
                    137,
                  ).withAlpha(51),
                  highlightColor: const Color.fromARGB(
                    255,
                    21,
                    145,
                    137,
                  ).withAlpha(25),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    child: Image.asset(
                      asset,
                      height: 36,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // IMPROVED: Tips Card dengan desain modern, gradient, dan animasi smooth
  Widget _tipsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required int index,
    required Color backgroundColor,
    VoidCallback? onTap,
  }) {
    final isActive = (_currentPage == index);
    final scale = isActive ? 1.0 : 0.92;
    final opacity = isActive ? 1.0 : 0.75;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      transform: Matrix4.identity()..scale(scale),
      alignment: Alignment.center,
      width: 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundColor, backgroundColor.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(isActive ? 0.5 : 0.3),
            blurRadius: isActive ? 24 : 16,
            offset: Offset(0, isActive ? 12 : 8),
            spreadRadius: isActive ? 2 : 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white.withOpacity(0.3),
          highlightColor: Colors.white.withOpacity(0.2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: opacity,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon dengan background circle dan glow effect
                  Row(
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.8, end: isActive ? 1.0 : 0.9),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.3),
                                    blurRadius: isActive ? 16 : 8,
                                    spreadRadius: isActive ? 2 : 0,
                                  ),
                                ],
                              ),
                              child: Icon(icon, color: Colors.white, size: 32),
                            ),
                          );
                        },
                      ),
                      const Spacer(),
                      // Decorative element
                      if (isActive)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.eco,
                                      color: Colors.white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Tips',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Title dengan efek shimmer
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Divider dengan gradient
                  Container(
                    height: 3,
                    width: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.3)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Subtitle dengan line height optimal
                  Flexible(
                    child: Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.95),
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Action indicator
                  if (isActive)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                'Tap untuk detail',
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 14,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== Card 1: Service Account dengan Jadwal =====
  Widget _buildServiceAccountCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // (Removed) Top "Tambah akun layanan" button — action moved to Detail button
        const SizedBox(height: 8),
        // Service account card
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        elevation: 4,
        shadowColor: Colors.black.withAlpha(51),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _akunList.isNotEmpty ? _showAkunSelector : null,
          child: Container(
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage("assets/images/bg1.png"),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(18),
            child: Stack(
              children: [
                // Main content row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon box
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/images/home.jpeg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.home_outlined,
                              size: 40,
                              color: Color.fromARGB(255, 21, 145, 137),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Service Account info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (child, anim) {
                      return FadeTransition(opacity: anim, child: child);
                    },
                    child: _akunList.isEmpty
                        ? Column(
                            key: const ValueKey('empty_account'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Belum ada akun",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Tambahkan akun layanan sampah",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color.fromARGB(
                                    255,
                                    21,
                                    145,
                                    137,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            key: ValueKey(
                              'account_${_selectedAkun?['id_akun'] ?? 'all'}',
                            ),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Badge: Status inactive (jika ada)
                              Row(
                                children: [
                                  // Badge status inactive (prioritas tinggi)
                                  if (_selectedAkun != null &&
                                      _selectedAkun!['status']
                                              ?.toString()
                                              .toLowerCase() ==
                                          'inactive')
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade600,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.warning,
                                            color: Colors.white,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            "Akun Tidak Aktif",
                                            style: GoogleFonts.poppins(
                                              fontSize: 9,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Nama Akun (Bold)
                              Text(
                                _selectedAkun != null
                                    ? _selectedAkun!['nama'] ?? 'Unknown'
                                    : _akunList.isNotEmpty
                                    ? _akunList.first['nama'] ?? 'Unknown'
                                    : 'No Account',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              // Kelurahan dengan icon
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _selectedAkun != null &&
                                              _selectedAkun!['kelurahan'] !=
                                                  null
                                          ? _selectedAkun!['kelurahan']
                                          : _akunList.isNotEmpty &&
                                                _akunList.first['kelurahan'] !=
                                                    null
                                          ? _akunList.first['kelurahan']
                                          : '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Jadwal Pengambilan dengan background berbeda (CLICKABLE) - DUMMY DATA
                              InkWell(
                                onTap: () {
                                  // Navigate ke JadwalPengambilanScreen dengan ID dari selected akun
                                  int? serviceAccountId;
                                  
                                  if (_selectedAkun != null) {
                                    // Coba ambil dari id_akun atau id, kemudian parse ke int
                                    final idValue = _selectedAkun!['id_akun'] ?? _selectedAkun!['id'];
                                    if (idValue != null) {
                                      serviceAccountId = int.tryParse(idValue.toString());
                                    }
                                  }
                                  
                                  // Fallback ke 1 jika tidak ada
                                  serviceAccountId ??= 1;
                                  
                                  print('[SEARCH] Navigating to JadwalPengambilanScreen with ID: $serviceAccountId');
                                  
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => JadwalPengambilanScreen(
                                        serviceAccountId: serviceAccountId,
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2F1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF00897B),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: const Color(0xFF00897B),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _selectedAkun != null && _selectedAkun!['hari_pengangkutan'] != null
                                              ? () {
                                                  // Cek apakah hari_pengangkutan sudah mengandung jam (ada karakter '•' atau ':')
                                                  final hariPengangkutan = _selectedAkun!['hari_pengangkutan'].toString();
                                                  if (hariPengangkutan.contains('•') || hariPengangkutan.contains(':')) {
                                                    // Sudah ada jam, tampilkan apa adanya
                                                    return "Jadwal: $hariPengangkutan";
                                                  } else {
                                                    // Belum ada jam, tambahkan jam_pengangkutan
                                                    final jamPengangkutan = _selectedAkun!['jam_pengangkutan'] ?? '07:00';
                                                    return "Jadwal: $hariPengangkutan • $jamPengangkutan";
                                                  }
                                                }()
                                              : "Jadwal: Belum diatur",
                                          style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            color: const Color(0xFF00897B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 10,
                                        color: const Color(0xFF00897B),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Tombol aksi di samping kanan: tampilkan berbeda bergantung pada ada akun atau tidak
                    if (_akunList.isEmpty) ...[
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () async {
                              // Buka halaman tambah akun
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TambahAkunLayananScreen(),
                                ),
                              );
                              // Refresh daftar akun setelah kembali
                              await _loadAkunLayanan(selectLastIfNotFound: true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 21, 145, 137),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              "+ Buat",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: () async {
                              // Tampilkan shimmer loading
                              _showShimmerLoading(context);

                              // Delay sebentar untuk efek shimmer terlihat
                              await Future.delayed(const Duration(milliseconds: 500));

                              // Buka detail akun yang dipilih
                              final currentAccountMap = _selectedAkun ?? _akunList.first;

                              final serviceAccount = ServiceAccount(
                                id: currentAccountMap['id_akun']?.toString() ?? '0',
                                name: currentAccountMap['nama']?.toString() ?? '',
                                address: currentAccountMap['alamat']?.toString() ?? '',
                                latitude: 0.0,
                                longitude: 0.0,
                                status: 'active',
                                contactPhone: currentAccountMap['no_telepon']?.toString(),
                                kecamatanName: currentAccountMap['kecamatan']?.toString(),
                                kelurahanName: currentAccountMap['kelurahan']?.toString(),
                                rwName: currentAccountMap['rw']?.toString(),
                                hariPengangkutan: currentAccountMap['hari_pengangkutan']?.toString(),
                              );

                              // Tutup shimmer loading
                              if (mounted) Navigator.of(context).pop();

                              // Navigate ke detail
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DetailAkunLayananScreen(akun: serviceAccount),
                                ),
                              );

                              // Refresh setelah kembali dari detail
                              await _loadAkunLayanan(selectLastIfNotFound: true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 21, 145, 137),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "Detail",
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              
              // Ganti akun layanan button - positioned at top right
              if (_akunList.isNotEmpty)
                Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _showAkunSelector,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Ganti akun layanan",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color.fromARGB(255, 233, 33, 33),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color.fromARGB(255, 230, 47, 37),
                                shape: BoxShape.circle,
                              ),
                              child: Image.asset(
                                'assets/images/switch account.png',
                                width: 14,
                                height: 16,
                                color: Colors.white,
                              ),  
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
        ),
      ],
    );
  }

  // ===== Card 2: Tagihan & Pembayaran =====
  Widget _buildTagihanCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        elevation: 4,
        shadowColor: Colors.black.withAlpha(51),
        child: Container(
          decoration: BoxDecoration(
            image: const DecorationImage(
              image: AssetImage("assets/images/bg1.png"),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // icon box
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(10),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Image.asset("assets/images/wallet.png", height: 30),
              ),
              const SizedBox(width: 12),

              // Tagihan info (animated)
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, anim) {
                    return FadeTransition(opacity: anim, child: child);
                  },
                  child: _isLoadingInvoices
                      ? Column(
                          key: const ValueKey('loading_card'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Memuat tagihan...",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        )
                      : _akunList.isEmpty
                      ? Column(
                          key: const ValueKey('empty_card'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Belum ada akun",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Buat akun layanan dulu",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color.fromARGB(255, 21, 145, 137),
                              ),
                            ),
                          ],
                        )
                      : _unpaidInvoices.isEmpty
                      ? Column(
                          key: const ValueKey('no_invoice_card'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Tidak ada tagihan",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Konfirmasi pengambilan sampah untuk membuat tagihan",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color.fromARGB(255, 21, 145, 137),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          key: ValueKey('invoice_${_unpaidInvoices.length}'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Tagihan",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormat.format(_totalUnpaidAmount),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Semua akun (${_unpaidInvoices.length} tagihan)",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color.fromARGB(255, 21, 145, 137),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // tombol Bayar
              const SizedBox(width: 12),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed:
                      (_isLoadingInvoices ||
                          _akunList.isEmpty ||
                          _unpaidInvoices.isEmpty)
                      ? null
                      : () async {
                          await _handlePaymentClick();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 21, 145, 137),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: Text(
                    "Bayar",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== Helper Methods untuk Artikel =====

  /// Build artikel card dengan gambar dan title
  Widget _buildArtikelCard(ArtikelModel artikel) {
    return InkWell(
      onTap: () {
        // Navigate ke halaman detail artikel dengan objek artikel lengkap
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArtikelDetailScreen(article: artikel),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 180,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: artikel.imageUrl != null && artikel.imageUrl!.isNotEmpty
                  ? Image.network(
                      artikel.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.teal.shade100,
                          child: const Icon(
                            Icons.article,
                            size: 60,
                            color: Colors.teal,
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey.shade200,
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.teal.shade100,
                      child: const Icon(
                        Icons.article,
                        size: 60,
                        color: Colors.teal,
                      ),
                    ),
            ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
            // Title at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      artikel.title,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (artikel.excerpt != null && artikel.excerpt!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          artikel.excerpt!,
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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

  /// Build shimmer loading untuk artikel
  Widget _buildArtikelShimmer() {
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: 280,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Build empty state untuk artikel
  Widget _buildEmptyArtikel() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.article_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              "Belum ada artikel",
              style: GoogleFonts.poppins(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () async {
                await _loadArtikel();
              },
              child: Text(
                "Muat Ulang",
                style: GoogleFonts.poppins(
                  color: Colors.teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for dashed border
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    // Create dashed path
    final dashPath = _createDashedPath(rrect, dashWidth, dashSpace);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashedPath(RRect rrect, double dashWidth, double dashSpace) {
    final path = Path();
    final rect = rrect.outerRect;
    final radius = rrect.tlRadius.x;

    // Top side
    double startX = rect.left + radius;
    final topY = rect.top;
    while (startX < rect.right - radius) {
      final endX = (startX + dashWidth).clamp(rect.left + radius, rect.right - radius);
      path.moveTo(startX, topY);
      path.lineTo(endX, topY);
      startX = endX + dashSpace;
    }

    // Right side
    double startY = rect.top + radius;
    final rightX = rect.right;
    while (startY < rect.bottom - radius) {
      final endY = (startY + dashWidth).clamp(rect.top + radius, rect.bottom - radius);
      path.moveTo(rightX, startY);
      path.lineTo(rightX, endY);
      startY = endY + dashSpace;
    }

    // Bottom side
    startX = rect.right - radius;
    final bottomY = rect.bottom;
    while (startX > rect.left + radius) {
      final endX = (startX - dashWidth).clamp(rect.left + radius, rect.right - radius);
      path.moveTo(startX, bottomY);
      path.lineTo(endX, bottomY);
      startX = endX - dashSpace;
    }

    // Left side
    startY = rect.bottom - radius;
    final leftX = rect.left;
    while (startY > rect.top + radius) {
      final endY = (startY - dashWidth).clamp(rect.top + radius, rect.bottom - radius);
      path.moveTo(leftX, startY);
      path.lineTo(leftX, endY);
      startY = endY - dashSpace;
    }

    // Top-left corner
    _drawDashedArc(path, rect.left + radius, rect.top + radius, radius, 180, 270, dashWidth, dashSpace);

    // Top-right corner
    _drawDashedArc(path, rect.right - radius, rect.top + radius, radius, 270, 360, dashWidth, dashSpace);

    // Bottom-right corner
    _drawDashedArc(path, rect.right - radius, rect.bottom - radius, radius, 0, 90, dashWidth, dashSpace);

    // Bottom-left corner
    _drawDashedArc(path, rect.left + radius, rect.bottom - radius, radius, 90, 180, dashWidth, dashSpace);

    return path;
  }

  void _drawDashedArc(Path path, double cx, double cy, double radius, double startAngle, double endAngle, double dashWidth, double dashSpace) {
    final totalAngle = endAngle - startAngle;
    final circumference = (totalAngle / 360) * 2 * 3.14159 * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < dashCount; i++) {
      final angle1 = startAngle + (totalAngle * i * (dashWidth + dashSpace) / circumference);
      final angle2 = startAngle + (totalAngle * (i * (dashWidth + dashSpace) + dashWidth) / circumference);

      final x1 = cx + radius * cos(angle1 * 3.14159 / 180);
      final y1 = cy + radius * sin(angle1 * 3.14159 / 180);
      final x2 = cx + radius * cos(angle2 * 3.14159 / 180);
      final y2 = cy + radius * sin(angle2 * 3.14159 / 180);

      path.moveTo(x1, y1);
      path.lineTo(x2, y2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

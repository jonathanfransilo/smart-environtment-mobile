import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'notification_screen.dart';
import 'tips_detail_screen.dart';
import 'payment_method_screen.dart';
import '../../services/invoice_service.dart';
import '../../services/service_account_service.dart';
import '../../services/notification_helper.dart';
import '../../services/resident_pickup_service.dart';
import '../../services/user_storage.dart';
import '../../models/service_account.dart';
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

  // Invoice/Tagihan state
  final InvoiceService _invoiceService = InvoiceService();
  final ResidentPickupService _pickupService = ResidentPickupService();
  List<Map<String, dynamic>> _unpaidInvoices = [];
  double _totalUnpaidAmount = 0;
  bool _isLoadingInvoices = false;

  // Jadwal Pengambilan state
  String? _nextPickupSchedule; // Format: "Senin • 02:00"
  bool _isLoadingSchedule = false;

  // Currency formatter
  final currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  // TIPS CARD: Page Controller dan state halaman saat ini
  final PageController _tipsController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data ketika screen menjadi visible lagi (misalnya setelah kembali dari screen detail)
    // Ini akan memastikan jadwal selalu update
    if (mounted && _hasLoadedAkunOnce) {
      _refreshAllData();
    }
  }

  /// Refresh semua data dari API
  Future<void> _refreshAllData() async {
    await _loadAkunLayanan(selectLastIfNotFound: false);
    await _loadNextPickupSchedule();
    await _loadUnpaidInvoices();
  }

  @override
  void dispose() {
    _tipsController.dispose(); // Wajib dispose controller
    super.dispose();
  }

  Future<void> _initAll() async {
    await _loadUser();
    await _loadAkunLayanan(selectLastIfNotFound: true);
    await _loadUnreadNotif();
    await _loadUnpaidInvoices();
    await _loadNextPickupSchedule(); // Load jadwal pickup
    _hasLoadedAkunOnce = true;

    // Check dan trigger notifikasi otomatis
    await _checkAutomaticNotifications();
  }

  /// Check semua notifikasi otomatis (jadwal, tagihan, artikel)
  Future<void> _checkAutomaticNotifications() async {
    try {
      final helper = NotificationHelper();
      await helper.checkAndTriggerNotifications(
        serviceAccountId: _selectedAkun?['id']?.toString(),
      );
      // Refresh unread count setelah check notifikasi
      await _loadUnreadNotif();
    } catch (e) {
      print('Error checking automatic notifications: $e');
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

      // Filter by selected account if one is selected
      if (_selectedAkun != null && _akunList.length > 1) {
        final selectedAccountId = _selectedAkun!['id']?.toString();
        invoices = invoices.where((invoice) {
          final serviceAccount = invoice['service_account'];
          if (serviceAccount == null) return false;
          return serviceAccount['id']?.toString() == selectedAccountId;
        }).toList();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _unpaidInvoices = [];
        _totalUnpaidAmount = 0;
        _isLoadingInvoices = false;
      });
    }
  }

  /// Load next pickup schedule untuk akun yang dipilih
  /// Prioritas: API upcoming pickups > hari_pengangkutan dari service account
  Future<void> _loadNextPickupSchedule() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSchedule = true;
    });

    try {
      // Ambil akun yang dipilih
      final currentAccount =
          _selectedAkun ?? (_akunList.isNotEmpty ? _akunList.first : null);

      if (currentAccount == null) {
        if (!mounted) return;
        setState(() {
          _nextPickupSchedule = null;
          _isLoadingSchedule = false;
        });
        return;
      }

      final serviceAccountId =
          currentAccount['id_akun']?.toString() ??
          currentAccount['id']?.toString();

      if (serviceAccountId == null) {
        if (!mounted) return;
        setState(() {
          _nextPickupSchedule = null;
          _isLoadingSchedule = false;
        });
        return;
      }

      print('🔄 [HomeScreen] Loading pickup schedule for account: $serviceAccountId');

      // Fetch upcoming pickups dari API - ini yang terbaru dari database
      final (success, message, pickups) = await _pickupService
          .getUpcomingPickups(serviceAccountId: serviceAccountId);

      print('📡 [HomeScreen] API Response - Success: $success, Pickups count: ${pickups?.length}');

      if (success && pickups != null && pickups.isNotEmpty) {
        // Ambil pickup pertama (yang paling dekat)
        final nextPickup = pickups.first;
        final scheduleInfo =
            nextPickup['schedule_info'] as Map<String, dynamic>?;
        final dayName = nextPickup['day_name'] as String? ?? '';

        print('📅 [HomeScreen] Next pickup day: $dayName, schedule_info: $scheduleInfo');

        if (scheduleInfo != null) {
          final timeStart = scheduleInfo['time_start'] as String? ?? '';
          final timeEnd = scheduleInfo['time_end'] as String? ?? '';
          final dayOfWeek = scheduleInfo['day_of_week'] as String? ?? '';

          // Gunakan day_name dari pickup (sudah diformat dalam bahasa Indonesia oleh API)
          // Format jadwal: "Senin • 08:00-10:00" atau "Senin • 08:00"
          String scheduleText = dayName.isNotEmpty ? dayName : dayOfWeek;
          if (timeStart.isNotEmpty) {
            scheduleText += ' • $timeStart';
            if (timeEnd.isNotEmpty && timeEnd != timeStart) {
              scheduleText += '-$timeEnd';
            }
          }

          print('✅ [HomeScreen] Formatted schedule: $scheduleText');

          if (!mounted) return;
          setState(() {
            _nextPickupSchedule = scheduleText;
            _isLoadingSchedule = false;
          });
          return;
        } else if (dayName.isNotEmpty) {
          // Jika tidak ada schedule_info, gunakan day_name saja
          print('✅ [HomeScreen] Using day_name only: $dayName');
          if (!mounted) return;
          setState(() {
            _nextPickupSchedule = dayName;
            _isLoadingSchedule = false;
          });
          return;
        }
      }

      // Fallback: Reload service account untuk mendapatkan hari_pengangkutan terbaru
      print('⚠️ [HomeScreen] No upcoming pickups, reloading service account data');
      await _loadAkunLayanan(selectLastIfNotFound: false);
      
      final updatedAccount =
          _selectedAkun ?? (_akunList.isNotEmpty ? _akunList.first : null);
      final hariPengangkutan = updatedAccount?['hari_pengangkutan']?.toString();
      
      print('📊 [HomeScreen] Hari pengangkutan from account: $hariPengangkutan');
      
      if (hariPengangkutan != null && hariPengangkutan.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _nextPickupSchedule = hariPengangkutan;
          _isLoadingSchedule = false;
        });
      } else {
        // Tidak ada jadwal sama sekali
        print('❌ [HomeScreen] No schedule available');
        if (!mounted) return;
        setState(() {
          _nextPickupSchedule = null;
          _isLoadingSchedule = false;
        });
      }
    } catch (e) {
      debugPrint('💥 [HomeScreen] Error loading pickup schedule: $e');

      // Fallback: Reload dan gunakan hari_pengangkutan jika terjadi error
      try {
        await _loadAkunLayanan(selectLastIfNotFound: false);
        final currentAccount =
            _selectedAkun ?? (_akunList.isNotEmpty ? _akunList.first : null);
        final hariPengangkutan = currentAccount?['hari_pengangkutan']?.toString();

        if (!mounted) return;
        setState(() {
          _nextPickupSchedule = hariPengangkutan;
          _isLoadingSchedule = false;
        });
      } catch (e2) {
        debugPrint('💥 [HomeScreen] Error in fallback: $e2');
        if (!mounted) return;
        setState(() {
          _nextPickupSchedule = null;
          _isLoadingSchedule = false;
        });
      }
    }
  }

  // Initial loader (name + shimmer)
  Future<void> _loadUser() async {
    // Gunakan UserStorage untuk mendapatkan nama user yang tersimpan saat login
    final savedName = await UserStorage.getUserName();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _username = savedName ?? "User";
      _isLoading = false;
    });
  }

  // Refresh nama user
  Future<void> _refreshUser() async {
    // Gunakan UserStorage untuk mendapatkan nama user terbaru
    final savedName = await UserStorage.getUserName();
    if (!mounted) return;
    setState(() {
      _username = savedName ?? "User";
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
              'status': account.status,
              'kecamatan': account.kecamatanName,
              'kelurahan': account.kelurahanName,
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
            final idx = akunList.indexWhere(
              (a) => a['id']?.toString() == _selectedAkun!['id']?.toString(),
            );
            if (idx != -1) {
              _selectedAkun = akunList[idx];
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
              _selectedAkun = akunList[idx];
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

  /// HIDDEN: Tampilkan bottom sheet untuk memilih akun (fitur multiple account)
  /// Uncomment jika ingin enable multiple account
  /* void _showAkunSelector() async {
    if (_akunList.isEmpty) {
      await Navigator.pushNamed(context, '/layanan-sampah');
      final added = await _loadAkunLayanan(selectLastIfNotFound: true);
      if (added) await _loadUnreadNotif();
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
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
                        await Navigator.pushNamed(context, '/layanan-sampah');
                        final added = await _loadAkunLayanan(
                          selectLastIfNotFound: true,
                        );
                        if (added) await _loadUnreadNotif();
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
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color.fromARGB(
                          255,
                          21,
                          145,
                          137,
                        ).withAlpha(31), // Sesuaikan warna
                        child: const Icon(
                          Icons.home,
                          color: Color.fromARGB(255, 21, 145, 137),
                        ),
                      ),
                      title: Text(
                        akun["nama"] ?? "Akun Layanan",
                        style: GoogleFonts.poppins(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        akun["alamat lengkap"] ?? "-",
                        style: GoogleFonts.poppins(fontSize: 13),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color.fromARGB(255, 21, 145, 137),
                            )
                          : null,
                      onTap: () async {
                        setState(() {
                          _selectedAkun = akun;
                        });
                        Navigator.pop(context);

                        // Reload invoices and schedule for selected account
                        await _loadUnpaidInvoices();
                        await _loadNextPickupSchedule();
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
  } */

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
      await _loadNextPickupSchedule(); // Reload schedule setelah tambah akun
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Halo ${_isLoading ? 'User' : _username},",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              "Selamat Datang",
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          // 🔔 Notifikasi dengan badge
          Stack(
            children: [
              IconButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  );
                  await _loadUnreadNotif();
                },
                icon: const Icon(Icons.notifications, color: Colors.black),
              ),
              if (_unreadNotifCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        _unreadNotifCount > 9 ? '9+' : '$_unreadNotifCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          IconButton(
            onPressed: () async {
              await Navigator.pushNamed(context, '/profile');
              await _refreshUser();
              await _refreshAllData(); // Refresh semua data termasuk jadwal
            },
            icon: const Icon(Icons.person, color: Colors.black),
          ),
        ],
      ),
      body: _isLoading ? _buildShimmer() : _buildHomeContent(),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () async {
        // Pull to refresh - reload semua data
        await _refreshAllData();
        await _loadUnreadNotif();
        await _checkAutomaticNotifications();
      },
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(), // Pastikan bisa di-scroll untuk pull to refresh
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
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                _menuItem(
                  "assets/images/keranjang.png",
                  "Riwayat Pengambilan\nSampah",
                  onTap: () async {
                    // Navigasi ke riwayat pengambilan sampah
                    if (_akunList.isEmpty) {
                      // Jika belum ada akun, tampilkan snackbar
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
                    } else {
                      // Jika sudah ada akun, buka halaman riwayat
                      final currentAccount = _selectedAkun ?? _akunList.first;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RiwayatPengambilanScreen(
                            serviceAccountId:
                                currentAccount['id_akun']?.toString() ?? '0',
                            accountName:
                                currentAccount['nama']?.toString() ?? 'Akun',
                          ),
                        ),
                      );
                    }
                  },
                ),
                /* HIDDEN: Menu untuk menambahkan akun layanan (di-hide untuk single account mode)
                _menuItem(
                  "assets/images/keranjang.png",
                  "Akun Layanan\nSampah",
                  onTap: () async {
                    await _openLayananSampahAndRefresh();
                  },
                ), */
                _menuItem(
                  "assets/images/rekening.png",
                  "Riwayat Pembayaran",
                  onTap: () {
                    Navigator.pushNamed(context, '/riwayat-pembayaran');
                  },
                ),
                _menuItem(
                  "assets/images/artikel.png",
                  "Artikel",
                  onTap: () {
                    Navigator.pushNamed(context, '/artikel');
                  },
                ),
                _menuItem(
                  "assets/images/pelanggaran.png",
                  "Pelaporan",
                  onTap: () {
                    Navigator.pushNamed(context, '/pelaporan');
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
            SizedBox(
              height: 180,
              child: PageView(
                controller: _tipsController,
                children: [
                  // Card dengan background gambar dari Google Drive
                  InkWell(
                    onTap: () {
                      // Navigate ke halaman Artikel (list)
                      Navigator.pushNamed(context, '/artikel');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 180,
                      width: 260,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: const DecorationImage(
                          image: NetworkImage(
                            "https://drive.google.com/uc?export=view&id=1qjMCUnULqvjAzzMtpd2v2jctliNJWi9G",
                          ),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        color: Colors.black45,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          "Perpanjangan Tanggung Jawab Produsen dan Implementasi di Indonesia",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Card dengan background gambar dari Google Drive
                  InkWell(
                    onTap: () {
                      // Navigate ke halaman Artikel (list)
                      Navigator.pushNamed(context, '/artikel');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 180,
                      width: 260,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: const DecorationImage(
                          image: NetworkImage(
                            "https://drive.google.com/uc?export=view&id=1rcruFRS7rrGgQP5whXAonFPEQfz27mMq",
                          ),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        color: Colors.black45,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          "5 Hal yang Perlu Anda Ketahui Tentang Extended Producer Responsibility (EPR)",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Card dengan background gambar dari Google Drive
                  InkWell(
                    onTap: () {
                      // Navigate ke halaman Artikel (list)
                      Navigator.pushNamed(context, '/artikel');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 180,
                      width: 260,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: const DecorationImage(
                          image: NetworkImage(
                            "https://drive.google.com/uc?export=view&id=1ZawfY_Ktp5ZVeQb4T1mVQ9qONZXVaKDO",
                          ),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        color: Colors.black45,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          "Tips Mengurangi Sampah Plastik di Kehidupan Sehari-hari",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Card dengan background gambar dari Google Drive
                  InkWell(
                    onTap: () {
                      // Navigate ke halaman Artikel (list)
                      Navigator.pushNamed(context, '/artikel');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 180,
                      width: 260,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        image: const DecorationImage(
                          image: NetworkImage(
                            "https://drive.google.com/uc?export=view&id=1DIdr3ulKtU5oagWsA4pufnTzhZ1S_9ge",
                          ),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.bottomLeft,
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        color: Colors.black45,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          "Manfaat Daur Ulang bagi Lingkungan dan Ekonomi",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                    backgroundColor: Colors.blue.shade600, // Biru untuk energi
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
                    backgroundColor: Colors.orange.shade700, // Oranye untuk air
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
                    backgroundColor:
                        Colors.purple.shade600, // Ungu/Pink untuk plastik
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
              Ink(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(13),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
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
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    child: Image.asset(
                      asset,
                      height: 38,
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
              // Icon box
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
                child: const Icon(
                  Icons.home_outlined,
                  size: 40,
                  color: Color.fromARGB(255, 21, 145, 137),
                ),
              ),
              const SizedBox(width: 12),

              // Service Account info
              Expanded(
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
                                color: const Color.fromARGB(255, 21, 145, 137),
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
                            // HIDDEN: Badge ganti akun (fitur multiple account di-hide)
                            // Uncomment jika ingin enable multiple account
                            /* if (_akunList.length > 1) ...[
                              InkWell(
                                onTap: _showAkunSelector,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color.fromARGB(
                                      255,
                                      21,
                                      145,
                                      137,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        "Tap untuk ganti",
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ], */
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
                                            _selectedAkun!['kelurahan'] != null
                                        ? _selectedAkun!['kelurahan']
                                        : _akunList.isNotEmpty &&
                                              _akunList.first['kelurahan'] != null
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
                            // Jadwal Pengambilan dengan background berbeda
                            if (_isLoadingSchedule)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.grey.shade600,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Memuat jadwal...",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (_nextPickupSchedule != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 14,
                                      color: Colors.orange.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        "Jadwal: $_nextPickupSchedule",
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Belum ada jadwal",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ),

              // Tombol Create/Detail
              const SizedBox(width: 12),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_akunList.isEmpty) {
                      // Jika belum ada akun, buka halaman create
                      await _openLayananSampahAndRefresh();
                    } else {
                      // Tampilkan shimmer loading
                      _showShimmerLoading(context);

                      // Delay sebentar untuk efek shimmer terlihat
                      await Future.delayed(const Duration(milliseconds: 500));

                      // Jika sudah ada akun, buka detail akun
                      final currentAccountMap =
                          _selectedAkun ?? _akunList.first;

                      // Konversi Map ke ServiceAccount object
                      final serviceAccount = ServiceAccount(
                        id: currentAccountMap['id_akun']?.toString() ?? '0',
                        name: currentAccountMap['nama']?.toString() ?? '',
                        address: currentAccountMap['alamat']?.toString() ?? '',
                        latitude: 0.0, // Default, bisa diubah jika ada data
                        longitude: 0.0, // Default, bisa diubah jika ada data
                        status: 'active',
                        contactPhone: currentAccountMap['no_telepon']
                            ?.toString(),
                        kecamatanName: currentAccountMap['kecamatan']
                            ?.toString(),
                        kelurahanName: currentAccountMap['kelurahan']
                            ?.toString(),
                        hariPengangkutan: currentAccountMap['hari_pengangkutan']
                            ?.toString(),
                      );

                      // Tutup shimmer loading
                      if (mounted) Navigator.of(context).pop();

                      // Navigate ke detail
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              DetailAkunLayananScreen(akun: serviceAccount),
                        ),
                      );

                      // Refresh setelah kembali dari detail
                      await _loadAkunLayanan(selectLastIfNotFound: true);
                      await _loadNextPickupSchedule();
                    }
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
                      Icon(
                        _akunList.isEmpty ? Icons.add : Icons.info_outline,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _akunList.isEmpty ? "Create" : "Detail",
                        style: GoogleFonts.poppins(
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
        ),
      ),
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
                child: Image.asset("assets/images/wallet.png", height: 40),
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
                                fontSize: 14,
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
                                fontSize: 16,
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
                              "Semua tagihan sudah dibayar",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
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
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PaymentMethodScreen(
                                invoices: _unpaidInvoices,
                              ),
                            ),
                          );

                          // Refresh if payment was successful
                          if (result == true) {
                            await _loadUnpaidInvoices();
                          }
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
}
